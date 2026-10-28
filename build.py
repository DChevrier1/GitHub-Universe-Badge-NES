#!/usr/bin/env python3
"""Build a portable app-only ZIP with Python's standard library."""
import ast
import io
import hashlib
from pathlib import Path
import zipfile
ROOT=Path(__file__).resolve().parent
APP=ROOT/'apps'/'nes'
FILES=['LICENSE_upstream.txt', 'UPSTREAM.md', '__init__.py', 'cartridge.py', 'cartridge_mmc3.py', 'emu.py', 'emu_mmc3.py', 'font5x7.py', 'games.json', 'icon.png', 'licenses/2048-MIT.txt', 'licenses/falling-MIT.txt', 'licenses/minekart-MIT.txt', 'provenance/2048/LICENSE.txt', 'provenance/2048/PROVENANCE.json', 'provenance/2048/README.md', 'provenance/2048/SOURCE_MANIFEST.json', 'provenance/2048/build.py', 'provenance/2048/source/LICENSE', 'provenance/2048/source/Makefile', 'provenance/2048/source/data/2048.chr', 'provenance/2048/source/data/board-background.nam', 'provenance/2048/source/nrom.cfg', 'provenance/2048/source/src/2048.s', 'provenance/2048/source/src/blit.s', 'provenance/2048/source/src/board.s', 'provenance/2048/source/src/controller.s', 'provenance/2048/source/src/defs.s', 'provenance/2048/source/src/drawing.s', 'provenance/2048/source/src/header.s', 'provenance/2048/source/src/nmi.s', 'provenance/2048/source/src/startup.s', 'provenance/2048/source/src/tests.s', 'provenance/2048/source/src/tile-lookups.s', 'provenance/2048/source/test/helpers.s', 'provenance/2048/source/test/test-board.s', 'provenance/README.md', 'provenance/falling/LICENSE.txt', 'provenance/falling/PROVENANCE.json', 'provenance/falling/README.md', 'provenance/minekart/INES1_CONVERSION.json', 'provenance/minekart/LICENSE.txt', 'provenance/minekart/PROVENANCE.json', 'provenance/minekart/README.md', 'provenance/minekart/normalize_header.py', 'roms/2048.nes', 'roms/falling.nes', 'roms/minekart-madness.nes']
DOCS=['README.md', 'NOTICE.md', 'HARDWARE.json', 'screenshots/library.png', 'screenshots/2048.png', 'screenshots/falling.png', 'screenshots/minekart-madness.png']
ROM_HASHES={'roms/falling.nes': 'e22b947542c2d7e595bf84725b333be7af8189c5965b9c53e356a249c7d79943', 'roms/minekart-madness.nes': '7defa774cdf37c66e651e90cb6b20922ac20b4fc47135a3a40f633f255100663', 'roms/2048.nes': 'b1468ace1dcbf374a5202a26707b3d1a2fb11924a79aab877079730fe4f72ed6'}
PROVENANCE_HASHES={'provenance/2048/LICENSE.txt': '3dc37fbf59c95ef331e6805509770320810444ba926d08334b6e20074959831b', 'provenance/2048/PROVENANCE.json': 'eb04efe81b5786b85466f43d0bec989733a6a46992688fb2b59f542ec85f3160', 'provenance/2048/README.md': '7913543af311d35b06338f367fa5a2805cf6617824058914d2c3e35df93e87e5', 'provenance/2048/SOURCE_MANIFEST.json': '59e1dd06ee22c145270734ab9bddf19cec9af4131c279ebad3a7740bb0b4eadc', 'provenance/2048/build.py': '65054f0bc01cd2c74f8799a3428e912483541acc6f28d6565dab38f48187ed5c', 'provenance/2048/source/LICENSE': '3dc37fbf59c95ef331e6805509770320810444ba926d08334b6e20074959831b', 'provenance/2048/source/Makefile': 'e68e1b56892145af7dba579ee4da59c2815678af623ddecaa74e1d306913d1ca', 'provenance/2048/source/data/2048.chr': '7571f94eadf99117cd35d4d5b5f4af2736bf5f7c46d139a8c2b5007ea13b4e9d', 'provenance/2048/source/data/board-background.nam': '362fad36af25f18b92a7ef475c909ec1e1abb438c59a0ca37d9b73bf42706f0e', 'provenance/2048/source/nrom.cfg': 'dcfac531cc899c14fab17ee47c0822c381c039ab0e8c3faf2a3b4995d16f5e14', 'provenance/2048/source/src/2048.s': 'a25f95fa5489ea6cad732519ec13cc6a44da2cf567312ddf01e7c4e19e1f38b6', 'provenance/2048/source/src/blit.s': '3ed69604cedb1ac1421452f697a4039e481175ca8dba9d1103ac9702827556f8', 'provenance/2048/source/src/board.s': 'c45203010dff6e5e9a2b2ffe40e761ba7c8dce22ba0a8ca46b3400c9f56281a8', 'provenance/2048/source/src/controller.s': 'adc4e24a6d603ec8b5875f271ce871947c481e36f8d88e1946d51839bebb4f67', 'provenance/2048/source/src/defs.s': 'ee74ab6e751dc218e081da347c2d482ea7fb6c738b4b264e4db0b5d2563b3f11', 'provenance/2048/source/src/drawing.s': 'dd88e3cccd0b1530d71f5d4b6d2ebb04392d6701ec2394f6bc1215e3d05e6822', 'provenance/2048/source/src/header.s': 'd9f3b50f3ec15caf0fa61208ff7de3da5220d75613323405d7960ad25649ce81', 'provenance/2048/source/src/nmi.s': 'b6e3a3c4db048b95995fb126a9c6eba87050b95485b1f2cd33a34fbdd87bd2e8', 'provenance/2048/source/src/startup.s': 'e95a73ad93e6cda6714082ee6fd9979c6801055653019ac16b8d82ae628af676', 'provenance/2048/source/src/tests.s': 'ca829cc07004622f3f99160c3260ba02b5805f44de1ddac004f4316db91239e9', 'provenance/2048/source/src/tile-lookups.s': 'de2702373c56f9daa6e11c22f0183ea9642c61233a4a6fbc3a07adc6875de5e1', 'provenance/2048/source/test/helpers.s': '2853e2460eaa2656e2e001a76fb141b529d40175f51e55851fdcfe4cefd78633', 'provenance/2048/source/test/test-board.s': 'df694dbea3a37b7729cbadae62691a7b37afd9e74c62c9ef1eade11a24fba385', 'provenance/README.md': 'f3182798f89f02babb091939ca01f79847a28f9b7df368a45174509f613c68ff', 'provenance/falling/LICENSE.txt': '030010f3b77794b439b35cb072e7097ebeee713cac44b2ec1c532cbed8b94acd', 'provenance/falling/PROVENANCE.json': 'fda7b35d8f209005e565854fea2c1cd899cef8497a800aadaba9c456d321f34a', 'provenance/falling/README.md': '1a65b037e62475729cd65cfa4613c8b774fe617f0afa8a2b3ee2317a11f45977', 'provenance/minekart/INES1_CONVERSION.json': '9aa9c2d8dd0d2f70f12f0cc136c4b736aacce69929f73948f22d9b6d06376f7d', 'provenance/minekart/LICENSE.txt': 'f46e7bb719edf69363e449637b960c4d157fd634117f3ffad5d8a728e2a2b75d', 'provenance/minekart/PROVENANCE.json': '8a49a0c9fd93741ead1b5bab66cad3d5d31421ffa7da660d8d0ce61adfa05574', 'provenance/minekart/README.md': '8d1ea1e20cefb31042b556a56122bd84c2466d7a92e603cab5e659be92ca052c', 'provenance/minekart/normalize_header.py': '4f7d3df91aa3461c51bcf031636aef6730633fa17fc6f67714e97823d6c5f02f'}
DOCUMENT_HASHES={'HARDWARE.json': '02f76bdcaa5858b352f68115de2d6208a0a1c59668e41585813a7a5340df6d5e'}
def build():
    destination=ROOT/'dist'
    if destination.is_symlink():raise ValueError('Build directory must not be a symlink')
    destination.mkdir(exist_ok=True)
    output=destination/(APP.name+'-badge.zip')
    if output.is_symlink():raise ValueError('Build output must not be a symlink')
    buffer=io.BytesIO()
    with zipfile.ZipFile(buffer,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name in FILES:
            path=APP/name
            if any(part.is_symlink() for part in (path, *path.parents) if part != ROOT.parent):raise ValueError('Symlink in package: '+name)
            data=path.read_bytes()
            if name in ROM_HASHES and hashlib.sha256(data).hexdigest()!=ROM_HASHES[name]:raise ValueError('Reviewed game checksum differs: '+name)
            if name in PROVENANCE_HASHES and hashlib.sha256(data).hexdigest()!=PROVENANCE_HASHES[name]:raise ValueError('Reviewed provenance checksum differs: '+name)
            if path.suffix=='.py' and APP.name!='nes':
                tree=ast.parse(data.decode())
                for node in ast.walk(tree):
                    if isinstance(node,(ast.Module,ast.FunctionDef,ast.ClassDef)) and node.body and isinstance(node.body[0],ast.Expr) and isinstance(node.body[0].value,ast.Constant) and isinstance(node.body[0].value.value,str):
                        node.body.pop(0)
                        if not node.body:node.body.append(ast.Pass())
                data=(ast.unparse(tree)+'\n').encode()
                compile(data,name,'exec')
            if path.suffix=='.py':compile(data,name,'exec')
            archive.writestr('apps/'+APP.name+'/'+name,data)
        archive.writestr('INSTALL.txt','Copy only apps/'+APP.name+' to the BADGER apps directory. Back up any existing custom app first. Keep every other file, especially secrets.py. Eject safely and restart. See README.md for full instructions.\n')
        for name in DOCS:
            path=ROOT/name
            if any(part.is_symlink() for part in (path, *path.parents) if part != ROOT.parent):raise ValueError('Symlink in documentation: '+name)
            data=path.read_bytes()
            if name in DOCUMENT_HASHES and hashlib.sha256(data).hexdigest()!=DOCUMENT_HASHES[name]:raise ValueError('Reviewed documentation checksum differs: '+name)
            archive.writestr(name,data)
    output.write_bytes(buffer.getvalue())
    print(output)
    return output
if __name__=='__main__':build()
