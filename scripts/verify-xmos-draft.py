"""Compare a native EasyEDA snapshot with the independent XU316 pin plan.

Usage: python scripts/verify-xmos-draft.py read.json components.json report.json
Only validates this page's connection identities, not a complete boot circuit.
"""
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
design = root / 'hardware/asio-card-reva'
def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))
semantic, geometry = read(sys.argv[1])['result'], read(sys.argv[2])['result']
golden = read(design / 'xu-pin-net-plan.json')
aliases = read(design / 'net-aliases.json')
parts = {c['designator']: c for c in semantic['components'] if c.get('componentType') == 'part'}
instances = {c['designator']: c for c in geometry['components'] if c.get('componentType') == 'part'}
actual = {p['number']: p for p in parts['U10']['pins']}
pin_state = {p['pinNumber']: p for p in instances['U10']['pins']}
errors = []
if set(actual) != {str(i) for i in range(1,66)}:
    errors.append('U10 must expose exactly pins 1..65')
for p in golden['pins']:
    number = str(p['pin'])
    found = actual.get(number, {})
    expected = aliases.get(p.get('net'), p.get('net'))
    if expected:
        if found.get('net') != expected:
            errors.append(f'U10.{number}: {found.get("net")} != {expected}')
    elif not pin_state.get(number, {}).get('noConnected'):
        errors.append(f'U10.{number}: missing intentional NC mark')
for c in read(design / 'xmos-capacitors.json'):
    ref = c['ref']
    nets = {p['number']: p['net'] for p in parts[ref]['pins']}
    if nets != {'1': 'GND', '2': c['net']}:
        errors.append(f'{ref}: unexpected pin nets {nets}')
    props = instances[ref]
    if props.get('supplierId') != 'UNSELECTED' or props.get('manufacturerId') != 'UNSELECTED':
        errors.append(f'{ref}: borrowed library procurement identity not cleared')
    if props.get('otherProperty', {}).get('Spec_ID') != c['spec']:
        errors.append(f'{ref}: missing/mismatched Spec_ID')
report = dict(
    scope='XMOS_CORE draft connection identity only',
    passed=not errors,
    xmos_pins_checked=65,
    capacitor_pins_checked=36,
    intended_nc_pins=14,
    populated_parts=len(parts),
    errors=errors,
    not_validated=['startup/flash/clock completion','power-tree implementation','visual layout','native ERC/DRC','PCB','hardware behavior'],
)
Path(sys.argv[3]).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
sys.exit(bool(errors))
