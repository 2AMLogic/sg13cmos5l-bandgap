#!/usr/bin/env python3
"""Geometry census for the #170 base-tie repair (test plan, item 1).

Walks a bandgap_top GDS hierarchy and reports, per gate-free NWell island
(the ten pnpMPA base wells), the Cont polygons that sit on base Activ
(Activ inside the well, outside pSD) and under Metal1 -- the contacts that
bridge the n+ base ring to its Metal1 ring -- plus the emitter-window
contacts, which must stay separate from the ring. Also counts stream-wide
raw Cont boxes and Cont overlapping nSD (7/0) (the two MOS well-tap islands).

Usage: census.py <top.gds>
"""
import sys

import klayout.db as kdb

ACT, GAT, CONT, NSD, M1, PSD, NW = (1, 0), (5, 0), (6, 0), (7, 0), (8, 0), (14, 0), (31, 0)


def regions(ly, cell, ld):
    it = cell.begin_shapes_rec(ly.find_layer(*ld))
    return kdb.Region(it).merged()


def raw_shape_count(ly, cell, ld):
    it = cell.begin_shapes_rec(ly.find_layer(*ld))
    return sum(1 for _ in it.each())


def main(path):
    ly = kdb.Layout()
    ly.read(path)
    top = ly.top_cell()
    print(f"# {path}: top={top.name} dbu={ly.dbu}")

    nw = regions(ly, top, NW)
    gat = regions(ly, top, GAT)
    act = regions(ly, top, ACT)
    psd = regions(ly, top, PSD)
    m1 = regions(ly, top, M1)
    nsd = regions(ly, top, NSD)
    cont = regions(ly, top, CONT)

    print(f"raw Cont boxes (hierarchy walk): {raw_shape_count(ly, top, CONT)}")
    print(f"merged Cont polygons overlapping nSD: {cont.interacting(nsd).count()}")
    print(
        f"NWell islands: {nw.count()} "
        f"(gate-carrying MOS wells: {nw.interacting(gat).count()}, "
        f"gate-free PNP wells: {nw.not_interacting(gat).count()})"
    )

    pnp_wells = nw.not_interacting(gat)
    in_well_psd = psd.inside(pnp_wells)

    total_bridged = 0
    for i, well in enumerate(sorted(pnp_wells.each(), key=lambda p: (p.bbox().left, p.bbox().bottom))):
        wr = kdb.Region(well)
        wb = well.bbox()
        base_activ = act.inside(wr).not_interacting(psd)
        emitter_activ = act.inside(wr).interacting(psd)
        wc = cont.interacting(wr)
        base_cont = wc.interacting(base_activ)
        base_bridged = base_cont.interacting(m1)
        emit_cont = wc.interacting(emitter_activ)
        emit_bridged = emit_cont.interacting(m1)
        total_bridged += base_bridged.count()
        print(
            f"PNP well {i:2d} bbox=({wb.left * ly.dbu:.2f},{wb.bottom * ly.dbu:.2f}): "
            f"baseActiv={base_activ.count()}p "
            f"baseCont={base_cont.count()}p bridged(Activ&M1)={base_bridged.count()}p "
            f"emitCont={emit_cont.count()}p emitBridged={emit_bridged.count()}p"
        )
    print(f"total bridged base contacts across PNP wells: {total_bridged}")

    base_all = act.inside(pnp_wells).not_interacting(psd)
    shared = cont.interacting(base_all).interacting(in_well_psd)
    print(f"contacts touching both base Activ and in-well pSD: {shared.count()}")



if __name__ == "__main__":
    main(sys.argv[1])
