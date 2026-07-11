import { Controller } from "@hotwired/stimulus"

// Click-to-focus for the read-only idea graph: light the clicked node and its
// neighborhood, dim the rest, show the full text in the detail panel.
// Clicking the background clears. No editing — the graph is a view.
export default class extends Controller {
  static targets = ["svg", "panel", "kind", "body"]

  focus(event) {
    event.stopPropagation()
    const node = event.currentTarget
    const id = node.dataset.nodeId
    const neighbors = (node.dataset.neighbors || "").split(",")

    this.svgTarget.classList.add("focused")
    this.svgTarget.querySelectorAll(".graph-node").forEach((g) => {
      g.classList.toggle("is-focus", g.dataset.nodeId === id)
      g.classList.toggle("is-neighbor", neighbors.includes(g.dataset.nodeId))
    })
    this.svgTarget.querySelectorAll(".graph-edge").forEach((edge) => {
      edge.classList.toggle("is-active", edge.dataset.from === id || edge.dataset.to === id)
    })

    this.kindTarget.textContent = node.dataset.nodeKind
    this.bodyTarget.textContent = node.dataset.body
    this.panelTarget.hidden = false
  }

  clear(event) {
    if (event.target.closest(".graph-node")) return

    this.svgTarget.classList.remove("focused")
    this.svgTarget.querySelectorAll(".graph-node").forEach((g) => {
      g.classList.remove("is-focus", "is-neighbor")
    })
    this.svgTarget.querySelectorAll(".graph-edge").forEach((edge) => {
      edge.classList.remove("is-active")
    })
    this.panelTarget.hidden = true
  }
}
