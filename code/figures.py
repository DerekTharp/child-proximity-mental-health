"""
figures.py
Event study and analysis figures.

All values read from Stata output CSVs. No hardcoded coefficients.
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE_DIR = os.path.join(PROJECT_ROOT, "output/tables")
FIG_DIR = os.path.join(PROJECT_ROOT, "output/figures")


def figure3_event_study_cesd():
    """Event study: CES-D around gain of nearby child."""
    df = pd.read_csv(os.path.join(TABLE_DIR, "table4_event_study_cesd.csv"))

    # Add the omitted period (t = -1, normalized to 0)
    omitted = pd.DataFrame({"coef": [0], "se": [0], "event_time": [-1],
                            "ci_lo": [0], "ci_hi": [0]})
    df = pd.concat([df, omitted]).sort_values("event_time").reset_index(drop=True)

    fig, ax = plt.subplots(figsize=(7, 4.5))

    # Confidence intervals
    ax.fill_between(df["event_time"], df["ci_lo"], df["ci_hi"],
                    alpha=0.15, color="#2c7bb6")

    # Point estimates
    ax.plot(df["event_time"], df["coef"], "o-", color="#2c7bb6",
            markersize=6, linewidth=1.5)

    # Reference lines
    ax.axhline(0, color="black", linewidth=0.5, linestyle="-")
    ax.axvline(-0.5, color="gray", linewidth=0.8, linestyle="--", alpha=0.6)

    # Labels
    ax.set_xlabel("Waves relative to gaining a nearby child", fontsize=11)
    ax.set_ylabel("Change in CES-D (0-8 scale)", fontsize=11)
    ax.set_title("")  # No title for publication figure

    ax.set_xticks(range(-4, 5))
    ax.set_xticklabels([str(x) for x in range(-4, 5)])
    ax.yaxis.set_major_formatter(ticker.FormatStrFormatter("%.02f"))

    # Annotations
    ax.annotate("First child\nwithin 10 mi", xy=(0, df.loc[df["event_time"] == 0, "coef"].values[0]),
                xytext=(1.5, 0.03), fontsize=9, color="gray",
                arrowprops=dict(arrowstyle="->", color="gray", lw=0.8))

    ax.tick_params(labelsize=10)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "figure3_event_study_cesd.pdf"), dpi=300)
    fig.savefig(os.path.join(FIG_DIR, "figure3_event_study_cesd.png"), dpi=300)
    plt.close(fig)
    print("  Saved figure3_event_study_cesd")


def figure2_ols_decomposition():
    """Progressive covariate addition showing selection decomposition."""
    df = pd.read_csv(os.path.join(TABLE_DIR, "table2_ols.csv"))

    coefs = df.iloc[0, 1:].astype(float).values
    ses = df.iloc[1, 1:].astype(float).values
    labels = ["Bivariate", "+ Demographics", "+ Health,\nmarital, age", "+ Wealth"]

    fig, ax = plt.subplots(figsize=(6, 4))

    x = range(len(labels))
    ax.bar(x, coefs, yerr=1.96 * ses, color=["#d7191c", "#abd9e9", "#2c7bb6", "#2c7bb6"],
           capsize=4, edgecolor="none", alpha=0.85)

    ax.axhline(0, color="black", linewidth=0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylabel("Coefficient on any child within 10 mi\n(CES-D, 0-8 scale)", fontsize=10)
    ax.tick_params(labelsize=9)

    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "figure2_ols_decomposition.pdf"), dpi=300)
    fig.savefig(os.path.join(FIG_DIR, "figure2_ols_decomposition.png"), dpi=300)
    plt.close(fig)
    print("  Saved figure2_ols_decomposition")


def figure1_proximity_by_wave():
    """Percentage with any child within 10 miles, by wave."""
    df = pd.read_csv(os.path.join(TABLE_DIR, "proximity_by_wave.csv"))

    # Wave-to-year mapping
    wave_year = {1: 1992, 2: 1994, 3: 1996, 4: 1998, 5: 2000, 6: 2002,
                 7: 2004, 8: 2006, 9: 2008, 10: 2010, 11: 2012, 12: 2014,
                 13: 2016, 14: 2018, 15: 2020, 16: 2022}
    df["year"] = df["wave"].map(wave_year)

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(df["year"], df["pct_any_near"] * 100, "o-", color="#2c7bb6",
            markersize=5, linewidth=1.5)

    ax.set_xlabel("Year", fontsize=11)
    ax.set_ylabel("% with any child within 10 miles", fontsize=11)
    ax.set_ylim(0, 100)
    ax.tick_params(labelsize=10)

    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "figure1_proximity_trend.pdf"), dpi=300)
    fig.savefig(os.path.join(FIG_DIR, "figure1_proximity_trend.png"), dpi=300)
    plt.close(fig)
    print("  Saved figure1_proximity_trend")


def figure4_loss_event_study():
    """Event study: CES-D around loss of nearby child."""
    csv_path = os.path.join(TABLE_DIR, "appendix_es_loss.csv")
    if not os.path.exists(csv_path):
        print("  Skipping figure4 (appendix_es_loss.csv not found)")
        return

    df = pd.read_csv(csv_path)
    omitted = pd.DataFrame({"coef": [0], "se": [0], "event_time": [-1],
                            "ci_lo": [0], "ci_hi": [0]})
    df = pd.concat([df, omitted]).sort_values("event_time").reset_index(drop=True)

    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.fill_between(df["event_time"], df["ci_lo"], df["ci_hi"],
                    alpha=0.15, color="#d7191c")
    ax.plot(df["event_time"], df["coef"], "o-", color="#d7191c",
            markersize=6, linewidth=1.5)
    ax.axhline(0, color="black", linewidth=0.5)
    ax.axvline(-0.5, color="gray", linewidth=0.8, linestyle="--", alpha=0.6)
    ax.set_xlabel("Waves relative to losing a nearby child", fontsize=11)
    ax.set_ylabel("Change in CES-D (0-8 scale)", fontsize=11)
    ax.set_xticks(range(-4, 5))
    ax.yaxis.set_major_formatter(ticker.FormatStrFormatter("%.02f"))
    ax.annotate("No child\nwithin 10 mi", xy=(0, df.loc[df["event_time"] == 0, "coef"].values[0]),
                xytext=(1.5, -0.05), fontsize=9, color="gray",
                arrowprops=dict(arrowstyle="->", color="gray", lw=0.8))
    ax.tick_params(labelsize=10)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "figure4_event_study_loss.pdf"), dpi=300)
    fig.savefig(os.path.join(FIG_DIR, "figure4_event_study_loss.png"), dpi=300)
    plt.close(fig)
    print("  Saved figure4_event_study_loss")


def figure5_clean_gainers():
    """Event study: CES-D for clean gainers only (no reversals)."""
    csv_path = os.path.join(TABLE_DIR, "appendix_es_clean_gainers.csv")
    if not os.path.exists(csv_path):
        print("  Skipping figure5 (appendix_es_clean_gainers.csv not found)")
        return

    df = pd.read_csv(csv_path)
    omitted = pd.DataFrame({"coef": [0], "se": [0], "event_time": [-1],
                            "ci_lo": [0], "ci_hi": [0]})
    df = pd.concat([df, omitted]).sort_values("event_time").reset_index(drop=True)

    fig, ax = plt.subplots(figsize=(7, 4.5))
    ax.fill_between(df["event_time"], df["ci_lo"], df["ci_hi"],
                    alpha=0.15, color="#2c7bb6")
    ax.plot(df["event_time"], df["coef"], "s-", color="#2c7bb6",
            markersize=6, linewidth=1.5)
    ax.axhline(0, color="black", linewidth=0.5)
    ax.axvline(-0.5, color="gray", linewidth=0.8, linestyle="--", alpha=0.6)
    ax.set_xlabel("Waves relative to gaining a nearby child", fontsize=11)
    ax.set_ylabel("Change in CES-D (0-8 scale)", fontsize=11)
    ax.set_xticks(range(-4, 5))
    ax.yaxis.set_major_formatter(ticker.FormatStrFormatter("%.02f"))
    ax.tick_params(labelsize=10)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "figure5_clean_gainers.pdf"), dpi=300)
    fig.savefig(os.path.join(FIG_DIR, "figure5_clean_gainers.png"), dpi=300)
    plt.close(fig)
    print("  Saved figure5_clean_gainers")


def figure6_nonmover_robustness():
    """Event study: nonmovers vs movers at gain event."""
    nm_path = os.path.join(TABLE_DIR, "appendix_es_nonmover_at_gain.csv")
    mv_path = os.path.join(TABLE_DIR, "appendix_es_mover_at_gain.csv")
    if not os.path.exists(nm_path) or not os.path.exists(mv_path):
        print("  Skipping figure6 (nonmover CSVs not found)")
        return

    nm = pd.read_csv(nm_path)
    mv = pd.read_csv(mv_path)

    # Add omitted period (t = -1)
    omitted = pd.DataFrame({"coef": [0], "se": [0], "event_time": [-1],
                            "ci_lo": [0], "ci_hi": [0]})
    nm = pd.concat([nm[["coef", "se", "event_time", "ci_lo", "ci_hi"]], omitted]) \
        .sort_values("event_time").reset_index(drop=True)
    mv = pd.concat([mv[["coef", "se", "event_time", "ci_lo", "ci_hi"]], omitted]) \
        .sort_values("event_time").reset_index(drop=True)

    fig, ax = plt.subplots(figsize=(7, 4.5))

    # Nonmovers (child moved closer)
    offset = -0.08
    ax.fill_between(nm["event_time"] + offset, nm["ci_lo"], nm["ci_hi"],
                    alpha=0.12, color="#2c7bb6")
    ax.plot(nm["event_time"] + offset, nm["coef"], "o-", color="#2c7bb6",
            markersize=6, linewidth=1.5, label="Parent nonmover (n = 7,676)")

    # Movers (parent relocated)
    offset = 0.08
    ax.fill_between(mv["event_time"] + offset, mv["ci_lo"], mv["ci_hi"],
                    alpha=0.12, color="#d7191c")
    ax.plot(mv["event_time"] + offset, mv["coef"], "s--", color="#d7191c",
            markersize=5, linewidth=1.2, label="Parent mover (n = 2,581)")

    ax.axhline(0, color="black", linewidth=0.5)
    ax.axvline(-0.5, color="gray", linewidth=0.8, linestyle="--", alpha=0.6)

    ax.set_xlabel("Waves relative to gaining a nearby child", fontsize=11)
    ax.set_ylabel("Change in CES-D (0-8 scale)", fontsize=11)
    ax.set_xticks(range(-4, 5))
    ax.yaxis.set_major_formatter(ticker.FormatStrFormatter("%.02f"))
    ax.legend(fontsize=9, frameon=False, loc="lower left")
    ax.tick_params(labelsize=10)

    fig.tight_layout()
    fig.savefig(os.path.join(FIG_DIR, "figure6_nonmover_robustness.pdf"), dpi=300)
    fig.savefig(os.path.join(FIG_DIR, "figure6_nonmover_robustness.png"), dpi=300)
    plt.close(fig)
    print("  Saved figure6_nonmover_robustness")


if __name__ == "__main__":
    print("Generating figures...")
    # figure1_proximity_by_wave()  # Not cited in manuscript; available as supplementary
    figure2_ols_decomposition()
    figure3_event_study_cesd()
    figure4_loss_event_study()
    figure5_clean_gainers()
    figure6_nonmover_robustness()
    print("Done.")
