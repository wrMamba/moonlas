"""Generate original LAS/WDP waveform fixtures with laspy and struct.
The expected filtered document is written independently, retaining the WDP pool.
No upstream fixtures or implementation are copied.
"""
import copy
import datetime
import io
import json
import struct
from pathlib import Path

import laspy
import numpy as np
from laspy.vlrs.vlrlist import VLRList

assert laspy.__version__ == "2.6.1"
assert np.__version__ == "2.2.6"
ROOT = Path(__file__).resolve().parents[1]

def literal(raw):
    return 'b"' + ''.join('\\x%02x' % b for b in raw) + '"'

def evlr(user, ident, text, payload):
    return struct.pack("<H16sHQ32s",0,user.encode(),ident,len(payload),text.encode())+payload

def make_las(minor, fmt, internal):
    h=laspy.LasHeader(point_format=fmt,version=f"1.{minor}")
    h.creation_date=datetime.date(2026,11,17)
    h.scales=np.array([0.01,0.02,0.05])
    h.offsets=np.array([100.,200.,300.])
    h.system_identifier="independent waveform"
    h.generating_software="laspy 2.6.1 + struct"
    h.extra_header_bytes=b"retained-header"
    h.extra_vlr_bytes=b"retained-before-points"
    # Assign the bit field directly: laspy 2.6.1 false-setters XOR instead of clear.
    h.global_encoding.value = 2 if internal else 4
    h.vlrs.append(laspy.VLR(user_id="LASF_Spec",record_id=100,description="descriptor",record_data=struct.pack("<BBIIdd",8,0,4,10,0.5,-1.0)))
    if minor==4:
        h.global_encoding.wkt=True
        h.vlrs.append(laspy.VLR(user_id="LASF_Projection",record_id=2112,description="WKT",record_data=b'LOCAL_CS["Test",UNIT["metre",1]]\x00'))
    las=laspy.LasData(h)
    las.X=np.arange(8,dtype=np.int32)*100-300
    las.Y=np.arange(8,dtype=np.int32)*-20+500
    las.Z=np.arange(8,dtype=np.int32)*50
    las.return_number=np.ones(8,dtype=np.uint8)
    las.number_of_returns=np.ones(8,dtype=np.uint8)
    las.classification=np.full(8,2,dtype=np.uint8)
    las.gps_time=np.arange(8)*0.25+1234.5
    las.wavepacket_index=np.ones(8,dtype=np.uint8)
    las.wavepacket_offset=np.arange(8,dtype=np.uint64)*4+60
    las.wavepacket_size=np.full(8,4,dtype=np.uint32)
    las.return_point_wave_location=np.arange(8,dtype=np.float32)*0.25
    las.x_t=np.full(8,0.5,dtype=np.float32)
    las.y_t=np.full(8,-0.25,dtype=np.float32)
    las.z_t=np.ones(8,dtype=np.float32)
    if fmt in [5,10]:
        las.red=np.arange(8,dtype=np.uint16)*100
        las.green=np.arange(8,dtype=np.uint16)*200
        las.blue=np.arange(8,dtype=np.uint16)*300
    if fmt==10: las.nir=np.arange(8,dtype=np.uint16)*400
    return las

def serialize(las, internal):
    las=laspy.LasData(copy.deepcopy(las.header), points=las.points.copy())
    sink=io.BytesIO()
    las.write(sink)
    raw=bytearray(sink.getvalue())
    point_end=len(raw)
    pool=bytes(range(32))
    wave=evlr("LASF_Spec",65535,"wave",pool)
    before=evlr("vendor",123,"before",b"unknown-metadata")
    after=evlr("LASF_Projection",2111,"math transform",b'PARAM_MT["Identity"]\x00')
    gap=b"opaque-post-point-gap"
    if las.header.version.minor==4:
        records=[before]+([wave] if internal else [])+[after]
        struct.pack_into("<QI",raw,235,point_end+len(gap),len(records))
        if internal: struct.pack_into("<Q",raw,227,point_end+len(gap)+len(before))
        raw+=gap+b"".join(records)+b"opaque-trailing-bytes"
    elif internal:
        struct.pack_into("<Q",raw,227,point_end+len(gap))
        raw+=gap+wave+b"opaque-trailing-bytes"
    else: raw+=gap+b"opaque-trailing-bytes"
    # Independently parse point records and EVLRs again with laspy.
    checked=laspy.read(io.BytesIO(raw))
    assert checked.header.point_count==len(las.points)
    assert np.array_equal(checked.wavepacket_offset,las.wavepacket_offset)
    return bytes(raw),wave

def main():
    lines=["// Generated independently by tools/generate_waveform_oracles.py.",""]
    cases=[]
    for minor,formats in [(3,[4,5]),(4,[4,5,9,10])]:
        for fmt in formats:
            for internal in [False,True]:
                las=make_las(minor,fmt,internal)
                raw,wdp=serialize(las,internal)
                filtered=laspy.LasData(copy.deepcopy(las.header), points=las.points.copy())
                filtered.points=las.points[[1,3,6]].copy()
                expected,_=serialize(filtered,internal)
                where="internal" if internal else "external"
                lines += [f'test "independent LAS1.{minor} format{fmt} {where} waveform/filter" {{',f'  let raw = {literal(raw)}','  let d = try { decode(raw) } catch { Invalid(m) => fail(m); e => raise e }','  assert_true((try { encode(d) } catch { Invalid(m) => fail(m); e => raise e }) == raw)',f'  let wdp = {literal(wdp)}']
                # Pass WDP in both modes; internal mode must use its embedded record.
                for i in range(8):
                    payload=bytes(range(i*4,i*4+4))
                    samples=[v*0.5-1.0 for v in payload]
                    lines += [f'  assert_eq(d.waveform_packet(d.points[{i}], external=Some(wdp)), {literal(payload)})',f'  assert_eq((try {{ d.waveform_samples(d.points[{i}], external=Some(wdp)) }} catch {{ Invalid(m) => fail(m); e => raise e }}), {samples})']
                lines += ['  let changed = try { d.with_points([d.points[1], d.points[3], d.points[6]]) } catch { Invalid(m) => fail(m); e => raise e }',f'  assert_true(encode(changed) == {literal(expected)})','  let reread = decode(encode(changed))','  assert_eq(reread.tail, d.tail)','}']
                cases.append(dict(minor=minor,format=fmt,storage=where,records=8,filtered_records=3,bytes=len(raw)))
    (ROOT/'waveform_reference_wbtest.mbt').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    (ROOT/'tools/waveform-oracle-manifest.json').write_text(json.dumps(dict(laspy='2.6.1',numpy='2.2.6',cases=cases),indent=2)+'\n',encoding='utf-8',newline='\n')
    print(f"{len(cases)} documents; {sum(c['records'] for c in cases)} waveform records; independent filtered output + amplitude checks")

if __name__=='__main__': main()
