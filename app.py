import streamlit as st
import pandas as pd
import urllib.parse  # Built-in package to fix URL spaces safely


# 1. Import the blueprint from your separate modular file
from tab1_executive import render_tab_1
from tab2_supply import render_tab_2
from tab3_reliability import render_tab_3
from tab4_optimization import render_tab_4

# Global App Configurations
st.set_page_config(layout="wide", page_title="SQL Analytics Portfolio")

# Center-aligned visible title using a small bit of standard HTML
st.html("<h1 style='text-align: center;'>Restaurant Analytics Engineering</h1>")



# Configure Your Live GitHub Subfolder Connection Bridge:

# Configure GitHub Data Stream Connection (Replace placeholder text)
GITHUB_USER = "Manni-star"
GITHUB_REPO = "Restaurant-Analytics-Engineering"
GITHUB_BRANCH = "main"

GITHUB_BASE_URL = f"https://raw.githubusercontent.com/{GITHUB_USER}/{GITHUB_REPO}/{GITHUB_BRANCH}/Rendered_Data/"

@st.cache_data
def load_portfolio_data(file_name):
    """Securely downloads and memory-caches your SQL outputs directly from GitHub."""
    # Cleanly converts spaces (' ') to URL format ('%20') automatically
    encoded_file_name = urllib.parse.quote(file_name)
    target_url = f"{GITHUB_BASE_URL}{encoded_file_name}"
    return pd.read_csv(target_url)





# Establish the 4 Master Top Tabs
tab1, tab2, tab3, tab4 = st.tabs([
    "Revenue & Market Momentum",
    "Supply Chain Volatility & Reorder Logic",
    "Supplier Reliability & Labor Operations",
    "Scenario Simulations & Profit Optimization (Advanced Analytics)"
])

with tab1:
    st.info("""
    **Executive Overview & Market Dynamics Matrix**  
    Provides C-Suite visibility into global financial velocity, geometric fulfillment footprints, and top-line operational metrics.
    """)
    
    # 2. CALL THE FUNCTION HERE to render the metric cards dynamically!
    render_tab_1(load_portfolio_data)

with tab2:
    st.info("""
    **Inventory Risk Engine & Reorder Point Logic**  
    Monitors daily consumption flows, tracks resource depletion rates, and flags critical ingredient shortages using a 60% maximum risk threshold.
    """)

    # 2. CALL THE FUNCTION HERE to render the metric cards dynamically!
    render_tab_2(load_portfolio_data)


with tab3:
    st.info("""
    **Supplier Dependency Concentration & Corporate Labor Match**  
    Evaluates vendor volatility via the Herfindahl-Hirschman Index (HHI), tracks lead-time delivery drift, and pairs operational risk with daily labor overhead.
    """)

    # 2. CALL THE FUNCTION HERE to render the metric cards dynamically!
    render_tab_3(load_portfolio_data)

with tab4:
    st.info("""
    **Interactive What-If Simulation Sandboxes & Strategic Pricing**  
    Models macroeconomic demand shocks, runs material price inflation scenarios, maps Pareto margin thresholds, and models customer retention cohort heatmaps.
    """)
    
    # 2. CALL THE FUNCTION HERE to render the metric cards dynamically!
    render_tab_4(load_portfolio_data)





























    

