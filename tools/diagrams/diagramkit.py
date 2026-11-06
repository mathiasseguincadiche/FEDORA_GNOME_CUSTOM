"""Describe a diagram once, emit an editable Draw.io source and a matching SVG.

The editorial palette uses white cards on an opaque off-white canvas, consistent
spacing, restrained blues and semantic green/amber states. Meaning never relies
on colour alone: optional and manual elements have a dashed border and label.
"""
from dataclasses import dataclass, field
from html import escape
from xml.sax.saxutils import quoteattr

FONT = "Arial, Helvetica, sans-serif"
TEXT = "#1A2C43"
LINE = "#547BB4"
STYLES = {
    # name: (fill, stroke, dashed)
    "main": ("#EAF2FF", "#346AC4", False),
    "box": ("#FFFFFF", "#C4D5E8", False),
    "data": ("#E8F6EF", "#198263", False),
    "warn": ("#FFF3DE", "#AC731B", False),
    "muted": ("#FFFFFF", "#7C8A9C", True),
}
TITLE_SIZE, LABEL_SIZE, SUB_SIZE, EDGE_SIZE = 29, 17, 13, 12
CHAR = 0.53  # conservative average glyph width / font size, checked at build time


@dataclass
class Node:
    id: str
    lines: list
    x: float
    y: float
    w: float
    h: float
    style: str = "box"


@dataclass
class Group:
    id: str
    title: str
    x: float
    y: float
    w: float
    h: float


@dataclass
class Edge:
    id: str
    src: str
    dst: str
    label: str = ""
    dashed: bool = False
    both: bool = False


@dataclass
class Diagram:
    name: str
    title: str
    desc: str
    width: int
    height: int
    nodes: list = field(default_factory=list)
    groups: list = field(default_factory=list)
    edges: list = field(default_factory=list)

    def type_sizes(self):
        # Presentation diagrams appear full-width in README and overview guides.
        # Slightly larger text lets their key message survive that reduction.
        if self.name in {"architecture-poste", "chaine-qualification"}:
            return 20, 16
        return LABEL_SIZE, SUB_SIZE

    def node(self, *args, **kwargs):
        self.nodes.append(Node(*args, **kwargs))

    def group(self, *args, **kwargs):
        self.groups.append(Group(*args, **kwargs))

    def edge(self, *args, **kwargs):
        self.edges.append(Edge(*args, **kwargs))

    # ---- checks -------------------------------------------------------------
    def check(self):
        label_size, sub_size = self.type_sizes()
        ids = [n.id for n in self.nodes] + [g.id for g in self.groups]
        assert len(ids) == len(set(ids)), f"{self.name}: duplicate ids"
        known = {n.id for n in self.nodes} | {g.id for g in self.groups}
        for e in self.edges:
            assert e.src in known and e.dst in known, f"{self.name}: edge {e.id} points nowhere"
        for n in self.nodes:
            for i, line in enumerate(n.lines):
                size = label_size if i == 0 else sub_size
                need = len(line) * size * CHAR + 24
                assert need <= n.w, f"{self.name}: '{line}' needs {need:.0f}px in {n.id} ({n.w}px)"
            need_h = label_size + (len(n.lines) - 1) * (sub_size + 6) + 22
            assert need_h <= n.h, f"{self.name}: {n.id} too short ({need_h:.0f} > {n.h})"
            assert 0 <= n.x and n.x + n.w <= self.width and 0 <= n.y and n.y + n.h <= self.height, \
                f"{self.name}: {n.id} outside the canvas"

    # ---- geometry -----------------------------------------------------------
    def _by_id(self):
        # Groups can be edge endpoints: one arrow then stands for the whole group.
        shapes = {g.id: Node(g.id, [], g.x, g.y, g.w, g.h) for g in self.groups}
        shapes.update({n.id: n for n in self.nodes})
        return shapes

    def _segment(self, e):
        nodes = self._by_id()
        a, b = nodes[e.src], nodes[e.dst]
        acx, acy = a.x + a.w / 2, a.y + a.h / 2
        bcx, bcy = b.x + b.w / 2, b.y + b.h / 2
        # Prefer vertical or horizontal lines when boxes overlap on one axis.
        if a.x < b.x + b.w and b.x < a.x + a.w:
            mid = (max(a.x, b.x) + min(a.x + a.w, b.x + b.w)) / 2
            acx = bcx = mid
        elif a.y < b.y + b.h and b.y < a.y + a.h:
            mid = (max(a.y, b.y) + min(a.y + a.h, b.y + b.h)) / 2
            acy = bcy = mid
        x1, y1 = self._clip(a, acx, acy, bcx, bcy)
        x2, y2 = self._clip(b, bcx, bcy, acx, acy)
        return x1, y1, x2, y2

    @staticmethod
    def _clip(n, px, py, tx, ty):
        """From point (px, py) inside n, move towards (tx, ty) until the border of n."""
        dx, dy = tx - px, ty - py
        cands = []
        if dx:
            for edge_x in (n.x, n.x + n.w):
                t = (edge_x - px) / dx
                if t > 0:
                    cands.append(t)
        if dy:
            for edge_y in (n.y, n.y + n.h):
                t = (edge_y - py) / dy
                if t > 0:
                    cands.append(t)
        t = min(cands) if cands else 0
        return px + dx * t, py + dy * t

    # ---- SVG ----------------------------------------------------------------
    def svg(self):
        label_size, sub_size = self.type_sizes()
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.width} {self.height}" '
               f'width="{self.width}" height="{self.height}" role="img" aria-labelledby="title desc">',
               f'  <title id="title">{escape(self.title)}</title>',
               f'  <desc id="desc">{escape(self.desc)}</desc>',
               '  <defs>',
               f'    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse">'
               f'<path d="M0,0 L10,5 L0,10 z" fill="{LINE}"/></marker>',
               '  </defs>',
               f'  <rect width="{self.width}" height="{self.height}" fill="#F7F9FC"/>',
               f'  <rect x="0" y="0" width="{self.width}" height="7" fill="#346AC4"/>',
               f'  <text x="40" y="57" font-family="{FONT}" font-size="{TITLE_SIZE}" font-weight="bold" fill="{TEXT}">{escape(self.title)}</text>']
        for g in self.groups:
            out.append(f'  <rect x="{g.x}" y="{g.y}" width="{g.w}" height="{g.h}" rx="18" fill="#FFFFFF" stroke="#D9E3EF" stroke-width="1.5"/>')
            out.append(f'  <text x="{g.x + 20}" y="{g.y + 33}" font-family="{FONT}" font-size="{SUB_SIZE + 2}" font-weight="bold" fill="#2959B4">{escape(g.title)}</text>')
        for e in self.edges:
            x1, y1, x2, y2 = self._segment(e)
            dash = ' stroke-dasharray="7 5"' if e.dashed else ""
            start = ' marker-start="url(#arrow)"' if e.both else ""
            out.append(f'  <line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{LINE}" stroke-width="2"{dash}{start} marker-end="url(#arrow)"/>')
        for n in self.nodes:
            fill, stroke, dashed = STYLES[n.style]
            dash = ' stroke-dasharray="7 5"' if dashed else ""
            out.append(f'  <rect x="{n.x}" y="{n.y}" width="{n.w}" height="{n.h}" rx="14" fill="{fill}" stroke="{stroke}" stroke-width="1.8"{dash}/>')
            total = label_size + (len(n.lines) - 1) * (sub_size + 6)
            y = n.y + (n.h - total) / 2 + label_size - 2
            for i, line in enumerate(n.lines):
                size = label_size if i == 0 else sub_size
                weight = ' font-weight="bold"' if i == 0 else ""
                out.append(f'  <text x="{n.x + n.w / 2:.1f}" y="{y:.1f}" text-anchor="middle" font-family="{FONT}" font-size="{size}"{weight} fill="{TEXT}">{escape(line)}</text>')
                y += (sub_size + 6)
        for e in self.edges:
            if not e.label:
                continue
            x1, y1, x2, y2 = self._segment(e)
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            w = len(e.label) * EDGE_SIZE * CHAR + 12
            out.append(f'  <rect x="{mx - w / 2:.1f}" y="{my - 11:.1f}" width="{w:.1f}" height="20" rx="4" fill="#FFFFFF"/>')
            out.append(f'  <text x="{mx:.1f}" y="{my + 4:.1f}" text-anchor="middle" font-family="{FONT}" font-size="{EDGE_SIZE}" font-style="italic" fill="{TEXT}">{escape(e.label)}</text>')
        out.append('</svg>')
        return "\n".join(out) + "\n"

    # ---- diagrams.net -------------------------------------------------------
    def drawio(self):
        label_size, sub_size = self.type_sizes()
        def label(lines):
            first = f"<b>{escape(lines[0])}</b>"
            rest = "".join(f'<br><span style="font-size:{sub_size}px">{escape(l)}</span>' for l in lines[1:])
            return first + rest

        cells = ['<mxCell id="0"/>', '<mxCell id="1" parent="0"/>',
                 f'<mxCell id="title" value={quoteattr(escape(self.title))} style="text;html=1;fontSize={TITLE_SIZE};fontStyle=1;'
                 f'fontColor={TEXT};fontFamily=Arial;align=left;verticalAlign=middle;" vertex="1" parent="1">'
                 f'<mxGeometry x="40" y="23" width="{self.width - 80}" height="46" as="geometry"/></mxCell>']
        for g in self.groups:
            cells.append(f'<mxCell id={quoteattr(g.id)} value={quoteattr(escape(g.title))} style="rounded=1;arcSize=6;whiteSpace=wrap;html=1;'
                         f'fillColor=#FFFFFF;strokeColor=#D9E3EF;fontColor=#2959B4;fontStyle=1;fontSize={SUB_SIZE + 2};fontFamily=Arial;'
                         f'verticalAlign=top;align=left;spacingLeft=19;spacingTop=10;" vertex="1" parent="1">'
                         f'<mxGeometry x="{g.x}" y="{g.y}" width="{g.w}" height="{g.h}" as="geometry"/></mxCell>')
        for n in self.nodes:
            fill, stroke, dashed = STYLES[n.style]
            style = (f"rounded=1;arcSize=12;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};strokeWidth=1.8;"
                     f"fontColor={TEXT};fontSize={label_size};fontFamily=Arial;" + ("dashed=1;dashPattern=7 5;" if dashed else ""))
            cells.append(f'<mxCell id={quoteattr(n.id)} value={quoteattr(label(n.lines))} style="{style}" vertex="1" parent="1">'
                         f'<mxGeometry x="{n.x}" y="{n.y}" width="{n.w}" height="{n.h}" as="geometry"/></mxCell>')
        for e in self.edges:
            style = (f"endArrow=block;endFill=1;html=1;strokeColor={LINE};strokeWidth=2;fontColor={TEXT};fontSize={EDGE_SIZE};"
                     f"fontStyle=2;fontFamily=Arial;labelBackgroundColor=#FFFFFF;"
                     + ("dashed=1;dashPattern=7 5;" if e.dashed else "")
                     + ("startArrow=block;startFill=1;" if e.both else ""))
            x1, y1, x2, y2 = self._segment(e)
            # Pin the attachment points so diagrams.net draws the same line as the SVG export.
            shapes = self._by_id()
            a, b = shapes[e.src], shapes[e.dst]
            style += (f"exitX={(x1 - a.x) / a.w:.4f};exitY={(y1 - a.y) / a.h:.4f};exitDx=0;exitDy=0;"
                      f"entryX={(x2 - b.x) / b.w:.4f};entryY={(y2 - b.y) / b.h:.4f};entryDx=0;entryDy=0;")
            cells.append(f'<mxCell id={quoteattr(e.id)} value={quoteattr(escape(e.label))} style="{style}" edge="1" parent="1" '
                         f'source={quoteattr(e.src)} target={quoteattr(e.dst)}><mxGeometry relative="1" as="geometry">'
                         f'<mxPoint x="{x1:.1f}" y="{y1:.1f}" as="sourcePoint"/><mxPoint x="{x2:.1f}" y="{y2:.1f}" as="targetPoint"/>'
                         f'</mxGeometry></mxCell>')
        body = "\n        ".join(cells)
        return (f'<mxfile host="app.diagrams.net" type="device">\n'
                f'  <diagram id={quoteattr(self.name)} name={quoteattr(self.title)}>\n'
                f'    <mxGraphModel dx="{self.width}" dy="{self.height}" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" '
                f'arrows="1" fold="1" page="1" pageScale="1" pageWidth="{self.width}" pageHeight="{self.height}" '
                f'background="#F7F9FC" math="0" shadow="0">\n      <root>\n        {body}\n      </root>\n    </mxGraphModel>\n'
                f'  </diagram>\n</mxfile>\n')
