"""
figure_dag.py
DAG (Directed Acyclic Graph) showing the selection problem
in estimating the effect of child proximity on mental health.
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIG_DIR = os.path.join(PROJECT_ROOT, "output/figures")

def figure1_dag():
    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.set_xlim(-0.5, 6.5)
    ax.set_ylim(-0.5, 4.5)
    ax.axis("off")

    # Node positions
    nodes = {
        "U":  (3.0, 4.0),   # Unobserved (top center)
        "H":  (1.0, 2.5),   # Health
        "W":  (5.0, 2.5),   # Wealth/SES
        "P":  (1.5, 0.5),   # Proximity (exposure)
        "M":  (4.5, 0.5),   # Mental health (outcome)
    }

    labels = {
        "U":  "Unobserved\n(personality,\npreferences)",
        "H":  "Health\nstatus",
        "W":  "Wealth /\nSES",
        "P":  "Child\nproximity",
        "M":  "Mental\nhealth",
    }

    # Draw nodes
    node_colors = {
        "U": "#e0e0e0",   # gray (unobserved)
        "H": "#d4e6f1",   # light blue
        "W": "#d4e6f1",   # light blue
        "P": "#aed6f1",   # medium blue (exposure)
        "M": "#aed6f1",   # medium blue (outcome)
    }

    for name, (x, y) in nodes.items():
        box_style = "round,pad=0.3" if name != "U" else "round,pad=0.3,rounding_size=0.15"
        linestyle = "--" if name == "U" else "-"
        bbox = dict(boxstyle=box_style, facecolor=node_colors[name],
                    edgecolor="black", linewidth=1.2, linestyle=linestyle)
        ax.text(x, y, labels[name], ha="center", va="center",
                fontsize=9, bbox=bbox, fontfamily="sans-serif")

    # Edges (arrows)
    arrow_props = dict(arrowstyle="-|>", color="black", lw=1.2,
                       connectionstyle="arc3,rad=0.1")
    arrow_props_dashed = dict(arrowstyle="-|>", color="gray", lw=1.0,
                              linestyle="--", connectionstyle="arc3,rad=0.1")
    arrow_props_causal = dict(arrowstyle="-|>", color="#2c7bb6", lw=2.0,
                              connectionstyle="arc3,rad=0.0")

    # U -> H, W, P, M (dashed, unobserved confounders)
    for target in ["H", "W", "P", "M"]:
        ax.annotate("", xy=nodes[target], xytext=nodes["U"],
                    arrowprops=arrow_props_dashed)

    # H -> P (health affects proximity — reverse causality)
    ax.annotate("", xy=(nodes["P"][0]+0.15, nodes["P"][1]+0.35),
                xytext=(nodes["H"][0]+0.15, nodes["H"][1]-0.35),
                arrowprops=arrow_props)

    # H -> M (health affects mental health)
    ax.annotate("", xy=(nodes["M"][0]-0.5, nodes["M"][1]+0.3),
                xytext=(nodes["H"][0]+0.5, nodes["H"][1]-0.3),
                arrowprops=arrow_props)

    # W -> P (wealth affects proximity / mobility)
    ax.annotate("", xy=(nodes["P"][0]+0.5, nodes["P"][1]+0.3),
                xytext=(nodes["W"][0]-0.5, nodes["W"][1]-0.3),
                arrowprops=arrow_props)

    # W -> M (wealth affects mental health)
    ax.annotate("", xy=(nodes["M"][0]-0.15, nodes["M"][1]+0.35),
                xytext=(nodes["W"][0]-0.15, nodes["W"][1]-0.35),
                arrowprops=arrow_props)

    # P -> M (the causal effect of interest — thick blue)
    ax.annotate("", xy=(nodes["M"][0]-0.6, nodes["M"][1]),
                xytext=(nodes["P"][0]+0.6, nodes["P"][1]),
                arrowprops=arrow_props_causal)

    # Label the causal path
    mid_x = (nodes["P"][0] + nodes["M"][0]) / 2
    ax.text(mid_x, 0.15, "Causal effect\nof interest",
            ha="center", va="center", fontsize=8, color="#2c7bb6",
            fontstyle="italic")

    # Legend
    legend_elements = [
        mpatches.Patch(facecolor="#e0e0e0", edgecolor="black",
                       linestyle="--", label="Unobserved (absorbed by person FE)"),
        plt.Line2D([0], [0], color="gray", linestyle="--", lw=1,
                   label="Unobserved confounding paths"),
        plt.Line2D([0], [0], color="black", lw=1.2,
                   label="Observed confounding paths"),
        plt.Line2D([0], [0], color="#2c7bb6", lw=2,
                   label="Causal path of interest"),
    ]
    ax.legend(handles=legend_elements, loc="lower right", fontsize=7.5,
              framealpha=0.9, edgecolor="gray")

    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "figure1_dag.pdf"), dpi=300, bbox_inches="tight")
    fig.savefig(os.path.join(FIG_DIR, "figure1_dag.png"), dpi=300, bbox_inches="tight")
    plt.close(fig)
    print("Saved figure1_dag")


if __name__ == "__main__":
    figure1_dag()
