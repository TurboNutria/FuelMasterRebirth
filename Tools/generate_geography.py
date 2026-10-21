#!/usr/bin/env python3
"""Builds the bundled province and municipality catalogues from the ministry's own data.

Province outlines are approximated by the convex hull of each province's stations, plus a
sample of station points used to break ties near borders. No third-party map data is used.

Usage:
    python3 Tools/generate_geography.py <EstacionesTerrestres.json> <Listados_Provincias.json>

Writes Packages/FuelMasterKit/Sources/DataLayer/Resources/{provinces,municipalities}.json
"""
import json
import pathlib
import sys

OUT = pathlib.Path(__file__).resolve().parent.parent / 'Packages/FuelMasterKit/Sources/DataLayer/Resources'
SAMPLES_PER_PROVINCE = 80


def number(text):
    return float(text.replace(',', '.'))


def in_spain(lat, lon):
    """Mainland, Balearics, Canaries, Ceuta and Melilla."""
    return 27.0 <= lat <= 44.5 and -18.5 <= lon <= 5.0


def spain_point(lat, lon):
    """Same rule as StationMapper.coordinate: swapped pairs are fixed, anything else outside Spain dropped."""
    if in_spain(lat, lon):
        return (round(lat, 5), round(lon, 5))
    if in_spain(lon, lat):
        return (round(lon, 5), round(lat, 5))
    return None


def convex_hull(points):
    points = sorted(set(points))
    if len(points) <= 2:
        return points

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def main(stations_path, provinces_path):
    stations = json.load(open(stations_path, encoding='utf-8-sig'))['ListaEESSPrecio']
    catalogue = json.load(open(provinces_path, encoding='utf-8-sig'))

    by_province, municipalities = {}, {}
    for s in stations:
        point = spain_point(number(s['Latitud']), number(s['Longitud (WGS84)']))
        if point is None:
            continue  # the ministry has a few stations at 0,0, which would stretch an outline across Spain
        by_province.setdefault(s['IDProvincia'], []).append(point)
        municipalities[s['IDMunicipio']] = {
            'id': s['IDMunicipio'], 'name': s['Municipio'].strip(), 'provinceID': s['IDProvincia'],
        }

    provinces = []
    for entry in catalogue:
        pid = entry['IDPovincia']  # sic: the ministry's key has a typo
        points = by_province.get(pid, [])
        if not points:
            continue
        lats = [p[0] for p in points]
        lons = [p[1] for p in points]
        step = max(1, len(points) // SAMPLES_PER_PROVINCE)
        provinces.append({
            'id': pid,
            'name': entry['Provincia'],
            'regionID': entry['IDCCAA'],
            'regionName': entry['CCAA'],
            'bounds': [min(lats), min(lons), max(lats), max(lons)],
            'hull': [list(p) for p in convex_hull(points)],
            'samples': [list(p) for p in sorted(points)[::step]],
        })

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'provinces.json').write_text(json.dumps(provinces, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    munis = sorted(municipalities.values(), key=lambda m: (m['provinceID'], m['name']))
    (OUT / 'municipalities.json').write_text(json.dumps(munis, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(f'{len(provinces)} provinces, {len(munis)} municipalities')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
