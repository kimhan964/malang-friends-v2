"""Apply modified game resources to a downloaded Godot 4.7.2 Windows pack.

Uses only the Python standard library. Close DesktopFriends before applying.
--check inspects differences without changing the pack.
"""
from pathlib import Path
import argparse,datetime,hashlib,json,os,struct

SOURCE=Path(__file__).resolve().parents[1]/'game'
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('runtime',type=Path,help='Directory containing DesktopFriends.exe and DesktopFriends.pck')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    pack=args.runtime.resolve()/'DesktopFriends.pck'
    with pack.open('rb') as stream:
        header=stream.read(128)
        if struct.unpack_from('<6I',header)!=(0x43504447,4,4,7,2,2):raise ValueError('Expected Godot 4.7.2 pack format')
        base,directory=struct.unpack_from('<QQ',header,24)
        size=stream.seek(0,2);stream.seek(directory)
        count=struct.unpack('<I',stream.read(4))[0];entries={}
        for _ in range(count):
            length=struct.unpack('<I',stream.read(4))[0]
            name=stream.read(length).rstrip(b'\0').decode('utf-8')
            entry=struct.unpack('<QQ16sI',stream.read(36))
            if entry[3] or base+entry[0]+entry[1]>directory:raise ValueError('Invalid entry')
            entries[name]=entry
    changed=[]
    for source in sorted(SOURCE.rglob('*')):
        if not source.is_file() or '.godot' in source.relative_to(SOURCE).parts:continue
        name=source.relative_to(SOURCE).as_posix()
        with source.open('rb') as stream:digest=hashlib.file_digest(stream,'md5').digest()
        if name not in entries or entries[name][2]!=digest:changed.append((name,source,digest))
    print('Changed resources:',len(changed))
    if args.check or not changed:return
    journal=pack.with_name(pack.name+'.source-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'-journal.json')
    journal.write_text(json.dumps({'size':size,'header':header.hex(),'changed':[n for n,_,_ in changed]},indent=2),encoding='utf-8')
    with pack.open('r+b') as stream:
        try:
            stream.seek(0,2)
            for name,source,digest in changed:
                stream.write(b'\0'*((-stream.tell())%32));offset=stream.tell()-base
                with source.open('rb') as incoming:
                    for chunk in iter(lambda:incoming.read(1024*1024),b''):stream.write(chunk)
                entries[name]=(offset,source.stat().st_size,digest,0)
            stream.write(b'\0'*((-stream.tell())%32));new_directory=stream.tell()
            stream.write(struct.pack('<I',len(entries)))
            for name,entry in sorted(entries.items()):
                encoded=name.encode('utf-8');encoded+=b'\0'*((-len(encoded))%4)
                stream.write(struct.pack('<I',len(encoded))+encoded+struct.pack('<QQ16sI',*entry))
            stream.flush();os.fsync(stream.fileno());stream.seek(32);stream.write(struct.pack('<Q',new_directory));stream.flush();os.fsync(stream.fileno())
        except BaseException:
            stream.seek(0);stream.write(header);stream.truncate(size);raise
    print('Updated:',pack)
    print('Recovery journal:',journal.name)
if __name__=='__main__':main()
