"""Mobile-first companion layouts for the seven desktop documentation diagrams.

Every card takes its wording from the *same* source diagram as its desktop
counterpart. Reflowing strings makes them readable at 300px without inventing
a separate description of the actual workflow. Edges are added deliberately:
adjacent cards are not assumed to depend on each other.
"""

from textwrap import wrap

from diagramkit import Diagram


class Stack:
    WIDTH = 360
    CARD_X = 22
    CARD_W = 316

    def __init__(self, original, title):
        self.source = original
        self.source_nodes = {node.id: node for node in original.nodes}
        self.diagram = Diagram(original.name + "-mobile", title, original.desc, self.WIDTH, 0)
        self.y = 90
        self.section_start = None
        self.section_no = 0

    @staticmethod
    def _reflow(lines):
        result = []
        for index, line in enumerate(lines):
            # The first line has a larger font; all others use the subtitle font.
            # A word too long for a card is split, never silently truncated.
            result.extend(wrap(line, width=27 if index == 0 else 32,
                               break_long_words=True, break_on_hyphens=False))
        return result

    def begin(self, title):
        assert self.section_start is None, "nested mobile groups are unsupported"
        self.section_start = self.y
        self.section_title = title
        self.y += 56

    def end(self):
        assert self.section_start is not None, "no mobile group is open"
        self.section_no += 1
        self.diagram.group(f"section{self.section_no}", self.section_title, 10,
                           self.section_start, 340, self.y - self.section_start - 2)
        self.section_start = None
        self.y += 34

    def card(self, source_id, *, name=None, lines=None, style=None):
        original = self.source_nodes[source_id]
        node_id = name or source_id
        content = self._reflow(lines if lines is not None else original.lines)
        _, subtitle_size = self.diagram.type_sizes()
        height = max(68, 20 + (len(content) - 1) * (subtitle_size + 6) + 35)
        self.diagram.node(node_id, content, self.CARD_X, self.y,
                          self.CARD_W, height, style or original.style)
        self.y += height + 33  # room for a clear vertical connector / breathing space
        return node_id

    def custom(self, node_id, lines, style="box"):
        content = self._reflow(lines)
        height = max(68, 20 + (len(content) - 1) * 23 + 35)
        self.diagram.node(node_id, content, self.CARD_X, self.y, self.CARD_W, height, style)
        self.y += height + 33
        return node_id

    def link(self, src, dst, *, label="", dashed=False, both=False):
        self.diagram.edge(f"mobile_edge_{len(self.diagram.edges)}", src, dst, label,
                          dashed=dashed, both=both)

    def finish(self):
        assert self.section_start is None
        self.diagram.height = self.y - 7
        # All mobile body text is >= 14px at the 300px insertion size.
        assert self.diagram.type_sizes()[1] * 300 / self.diagram.width >= 14
        self.diagram.check()
        return self.diagram


def mobile_counterpart(source):
    """Convert the original semantic model into a deliberately ordered portrait view."""
    name = source.name
    titles = {
        "architecture-poste": "Le poste Fedora",
        "sauvegarde-restauration": "Sauvegarde Borg",
        "ci-fusion-release": "CI, fusion et release",
        "centre-de-controle": "Le centre de contrôle",
        "laboratoire-gnome": "Laboratoire GNOME",
        "chaine-qualification": "Qualifier le poste",
        "acces-distant": "Accès distant",
    }
    b = Stack(source, titles[name])

    if name == "architecture-poste":
        b.begin("01 · POSTE ET USAGES")
        pc = b.card("pc")
        host = b.card("host")
        uses = b.custom("usages", ["Quatre usages", "Bureau GNOME · DevOps/KVM",
                                   "Jeux Vulkan · noyau Linux"])
        b.link(pc, host)
        b.link(host, uses)
        b.end()
        b.begin("02 · SSD DISTINCTS ET BORG")
        b.card("root")  # Independent system volume: no arrow to /data.
        data = b.card("data")
        borg = b.card("borg")
        b.link(data, borg)
        b.end()

    elif name == "sauvegarde-restauration":
        b.begin("01 · SOURCES SAUVEGARDÉES")
        for node in ("s1", "s2", "s3"):
            b.card(node)
        b.end()
        borg = b.card("borg")
        b.link("section1", borg)
        b.begin("02 · CONTRÔLER ET RESTAURER")
        checks = b.card("c1")
        stage = b.card("c2")
        copy = b.card("c3")
        # End at the new section's border: an arrow across its title would
        # obscure the heading in the narrow view.
        b.link(borg, "section2")
        b.link(stage, copy)
        b.end()
        b.begin("03 · NON COUVERT PAR BORG")
        b.card("m1")
        b.card("m2")
        b.end()

    elif name == "ci-fusion-release":
        b.begin("01 · WORKFLOW TESTS : 7 JOBS")
        for i in range(7):
            b.card(f"j{i}")
        b.end()
        b.begin("02 · CONTRATS ET CONTEXTES")
        contracts = b.card("contracts")
        b.card("other")  # Independent gate; not an outcome of contracts.
        b.link("section1", "section2")
        b.end()
        merge = b.card("merge")
        push = b.card("push")
        release = b.card("release")
        b.link("section2", merge)
        b.link(merge, push)
        b.link(push, release, dashed=True)

    elif name == "centre-de-controle":
        user = b.card("user")
        facade = b.card("cc")
        b.link(user, facade)
        b.begin("8 DOMAINES ET LEURS MOTEURS")
        for i in range(8):
            if i == 1:
                # The full path remains in the desktop source and guide; here
                # we keep the filename on one unbroken, readable line.
                b.card("d1", lines=["update", "update-system.sh"])
            else:
                b.card(f"d{i}")
        b.end()
        b.link(facade, "section1")

    elif name == "laboratoire-gnome":
        b.begin("RUNNER GITHUB JETABLE")
        ordered = ["t0", "t1", "t2", "t3", "b0", "b1", "b2"]
        for node in ordered:
            b.card(node)
        for before, after in zip(ordered, ordered[1:]):
            b.link(before, after)
        b.end()

    elif name == "chaine-qualification":
        stages = [("01 · AVANT INSTALLATION", ["b0", "b1", "b2"]),
                  ("02 · INSTALLER ET CONFIGURER", ["m0", "m1", "m2", "m3", "m4"]),
                  ("03 · QUALIFIER ET PUBLIER", ["a0", "a1", "a2"])]
        for index, (title, nodes) in enumerate(stages):
            b.begin(title)
            for node in nodes:
                b.card(node)
            b.end()
            for before, after in zip(nodes, nodes[1:]):
                b.link(before, after)
            if index < len(stages) - 1:
                b.link(nodes[-1], f"section{index + 2}")

    elif name == "acces-distant":
        b.begin("01 · CONNEXION CHIFFRÉE")
        tablet = b.card("tablet")
        tunnel = b.card("ts")
        pc = b.card("pc")
        b.link(tablet, tunnel, both=True)
        b.link(tunnel, pc, both=True)
        b.end()
        b.begin("02 · RÉVEIL SUR LE LAN")
        tablet = b.card("tablet", name="tablet_wol")
        tunnel = b.card("ts", name="ts_wol")
        relay = b.card("relay")
        pc = b.card("pc", name="pc_wol",
                    lines=["PC Fedora", "Magic Packet sur le réseau local"])
        b.link(tablet, tunnel)
        b.link(tunnel, relay)
        b.link(relay, pc, dashed=True)
        b.end()
        b.card("note")

    return b.finish()
