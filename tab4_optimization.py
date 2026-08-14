

import streamlit as st
import plotly.express as px
import pandas as pd

def render_tab_4(load_portfolio_data):
    """Encapsulates all scenario modeling, profit simulations, and cohort matrices for Tab 4."""

    # 1. Data Ingestion Phase
    m4_1_df = load_portfolio_data("SET-3 Mart-4 1.csv")
    m4_2_df = load_portfolio_data("SET-3 Mart-4 2.csv")



    # ==================================================
    # ZONE 1: MACRO SHOCK SIMULATIONS & STRESS-TESTING 
    # ==================================================


    # Injects an exact 15-pixel invisible gap on your canvas row
    st.html("<div style='height: 15px;'></div>")
 
     # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>🚨 Zone 1: Supply Chain Demand Shocks & Strategic Cost Volatility Simulations</h3>", 
        unsafe_allow_html=True
    )
 
    # Injects an exact 15-pixel invisible gap on your canvas row
    st.html("<div style='height: 10px;'></div>")
 
 
    # 1. Ingest Core Datasets from Portfolio Bridge
    m4_1_df = load_portfolio_data("SET-3 Mart-4 1.csv").copy()
    m4_2_df = load_portfolio_data("SET-3 Mart-4 2.csv").copy()
    
    
    # -------------------------------------------------------------------------
    # GLOBAL CONTROLS COHORT (Shared across both rows)
    # -------------------------------------------------------------------------
    drill_down_active = st.checkbox(
        "🔍 Activate Drill-Down Matrix (Expand All Materials)", 
        value=False,
        key="cb_zone1_drill_down",
        help="Deactivates the default Top 10 limit to render every single available material in the dataset portfolio."
    )
    
    # Unify unique codes across both files to build a clean master dropdown list
    all_distinct_ings = sorted(list(set(m4_1_df['ingredients'].unique()) |
                                    set(m4_2_df['ing_id'].unique()))
                               )
    
    selected_ingredients = st.multiselect(
        "Search / Isolate Material Codes for Side-by-Side Comparison (Section A and Section B):",
        options=all_distinct_ings,
        default=[],
        key="ms_zone1_ings"
    )


    # -------------------------------------------------------------------------
    # ROW 1 ANALYSIS: PHYSICAL DEMAND SURGES (SET-3 Mart-4 1)
    # -------------------------------------------------------------------------

    with st.container(border=True):

        # Centered alignment wrapper using standard HTML inline styles
        st.markdown(
            "<h5 style='text-align: center;'>📦 Section A: Physical Warehouse Volume Capacity Waves</h5>", 
            unsafe_allow_html=True
        )

        
        # Sort data by safety buffer needs so largest risks appear first
        m4_1_df = m4_1_df.sort_values(by='emergency_buffer_units', ascending=True)

        if len(selected_ingredients) > 0:
            filtered_demand_df = m4_1_df[m4_1_df['ingredients'].isin(selected_ingredients)]
        else:
            filtered_demand_df = m4_1_df if drill_down_active else m4_1_df.tail(10)



        col_growth, col_buffer = st.columns(2)


        #  Chart-1

        with col_growth:
            
            st.write("###### 📈 Baseline and Projected Annual Consumption")
            st.caption("Dark Blue represents baseline consumption. Light Blue shows the projected YoY scaling.")        

            # 1. Render the primary horizontal bar chart tracking projected consumption
            fig_growth = px.bar(
                filtered_demand_df,
                x='predicted_consmption_annual',
                y='ingredients',
                orientation='h',
                color_discrete_sequence=['#3498db'], # Light Blue
                labels={'predicted_consmption_annual': 'Annual Sourcing Packages'}
            )
            

            # 2. Inject the secondary inner baseline consumption bar directly on top of it
            fig_growth.add_bar(
                x=filtered_demand_df['consumption'],
                y=filtered_demand_df['ingredients'],
                orientation='h',
                marker=dict(color='#2c3e50'),
                name='Baseline Consumption', # Dark Navy Blue
                hovertemplate="<b>Material:</b> %{y}<br><b>Baseline Volume:</b> %{x:,.0f} units<extra></extra>"

            )

            # 🛠️ FIXED: Target trace index 0 directly to apply your projected hover template without failing!
            fig_growth.data[0].name = 'Projected Consumption'
            fig_growth.data[0].hovertemplate = "<b>Material:</b> %{y}<br><b>Projected Volume:</b> %{x:,.0f} units<extra></extra>"
            
            fig_growth.update_layout(
                margin=dict(l=10, r=10, t=10, b=10),
                height=340,
                barmode='overlay',
                showlegend=False,
                xaxis=dict(gridcolor='rgba(0,0,0,0.05)'),
                yaxis=dict(title=None))
            st.plotly_chart(fig_growth, use_container_width=True)
            
            

         #  Chart-2
                  
        with col_buffer:

            st.write("###### 🛡️ Additional Annual Shelf Capacity Requirement (Projected)")
            st.caption("Emergency Buffer requirement annually (Demand Shock Simulation Scenario).")

            # Build the adjoining bar chart tracking emergency buffers explicitly
            fig_buffer = px.bar(
                filtered_demand_df,
                x='emergency_buffer_units',
                y='ingredients',
                orientation='h',
                color='emergency_buffer_units',
                color_continuous_scale='Oranges', # Industrial Alert Orange
                labels={'emergency_buffer_units': 'Buffer Units (Safety Stock)'}
            )
            
            fig_buffer.update_traces(hovertemplate="<b>Material:</b> %{y}<br><b>Required Safety Buffer:</b> %{x:,.0f} units<extra></extra>")
            
            fig_buffer.update_layout(
                margin=dict(l=10, r=10, t=10, b=10),
                coloraxis_showscale=False,
                height=340,
                xaxis=dict(gridcolor='rgba(0,0,0,0.05)'),
                yaxis=dict(title=None))
            
            st.plotly_chart(fig_buffer, use_container_width=True)



    # -------------------------------------------------------------------------
    # ROW 2 ANALYSIS: FINANCIAL COST SHOCKS
    # -------------------------------------------------------------------------


    with st.container(border=True):
        
        # Centered alignment wrapper using standard HTML inline styles
        st.markdown(
            "<h5 style='text-align: center;'>🪙 Section B: Capital Procurement Cash Flow Inflation Shocks</h5>", 
            unsafe_allow_html=True
        )
        
        
        # DYNAMIC SLIDER: Control cost adjustments dynamically in real-time
        cost_slider_pct = st.slider(
            "Simulated Global Supply Chain Cost Inflation Rate Multiplier (% Surge):",
            min_value=0,
            max_value=100,
            value=15,
            step=1,
            format="%d%%",
            help="Simulates sudden wholesale cost increases. Modifying this recalculates the financial impact across ingredients."
        )
        
        # Calculate custom mathematical columns on the fly based on user's slider input value
        multiplier_coefficient = 1.0 + (cost_slider_pct / 100.0)
        m4_2_df['dynamic_inflated_cost'] = m4_2_df['base_cost'] * multiplier_coefficient
        m4_2_df['dynamic_cost_impact'] = m4_2_df['dynamic_inflated_cost'] - m4_2_df['base_cost']
        
        # Sort data strictly by cost impact so the hardest-hit categories sit at the bottom base
        m4_2_df = m4_2_df.sort_values(by='dynamic_cost_impact', ascending=True)
        
        if len(selected_ingredients) > 0:
            filtered_cost_df = m4_2_df[m4_2_df['ing_id'].isin(selected_ingredients)]
        else:
            filtered_cost_df = m4_2_df if drill_down_active else m4_2_df.tail(10)
            
            
        # THREE-COLUMN LAYOUT GRID: Allocates equal canvas space for Charts 3, 4, and 5 side-by-side
        col_chart3, col_chart4, col_chart5 = st.columns(3)
        
        with col_chart3:
            st.write("###### Static Baseline Procurement Cost")
            # Pristine static bar graph showing un-shocked capital levels
            fig_c3 = px.bar(
                filtered_cost_df, x='base_cost', y='ing_id', orientation='h',
                labels={'base_cost': 'Baseline Expenses ($)', 'ing_id': 'Material Code'}
            )
            
            # marker_color belongs right here update_trace
            fig_c3.update_traces(
                marker_color='#34495e',
                hovertemplate="<b>Material:</b> %{y}<br><b>Static Base Budget:</b> $%{x:,.2f}<extra></extra>"
            )
            
            fig_c3.update_layout(margin=dict(l=10, r=10, t=10, b=10), height=320, xaxis=dict(gridcolor='rgba(0,0,0,0.05)'), yaxis=dict(title=None))
            
            st.plotly_chart(fig_c3, use_container_width=True)

            
        with col_chart4:
            st.write("###### Dynamic Inflated Procurement Cost")
            # Interactive bar graph responding directly to your custom slider input value
            fig_c4 = px.bar(
                filtered_cost_df, x='dynamic_inflated_cost', y='ing_id', orientation='h',
                labels={'dynamic_inflated_cost': 'Total Inflated Capital ($)', 'ing_id': 'Material Code'}
            )
            # 🛠️ FIXED: marker_color belongs right here inside update_traces!
            fig_c4.update_traces(
                marker_color='#e67e22',
                hovertemplate="<b>Material:</b> %{y}<br><b>Simulated Volatility Cost:</b> $%{x:,.2f}<extra></extra>"
            )
            fig_c4.update_layout(margin=dict(l=10, r=10, t=10, b=10), height=320, xaxis=dict(gridcolor='rgba(0,0,0,0.05)'), yaxis=dict(title=None))
            st.plotly_chart(fig_c4, use_container_width=True)


            
        with col_chart5:
            st.write("###### Simulated Procurement Cost Deficit")
            # Visual shortfall chart isolating the exact procurement cash expansion drain
            fig_c5 = px.bar(
                filtered_cost_df, x='dynamic_cost_impact', y='ing_id', orientation='h',
                labels={'dynamic_cost_impact': 'Net Cost Expansion Delta ($)', 'ing_id': 'Material Code'}
            )
            # 🛠️ FIXED: Sets a bold solid Crimson Red to visually represent a financial loss or risk area
            fig_c5.update_traces(
                marker_color='#c0392b', 
                hovertemplate="<b>Material:</b> %{y}<br><b>Required Emergency Cash Lift:</b> $%{x:,.2f}<extra></extra>"
            )
            fig_c5.update_layout(margin=dict(l=10, r=10, t=10, b=10), height=320, xaxis=dict(gridcolor='rgba(0,0,0,0.05)'), yaxis=dict(title=None))
            st.plotly_chart(fig_c5, use_container_width=True)

        
    st.markdown("---")





    # =========================================================================
    # ZONE 2: PROFIT MAXIMIZATION & METRIC FLIP SUITE
    # =========================================================================



    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>🪙 Zone 2: Profit Maximization, NPM Margin Flip, & Menu Re-Pricing</h3>",
        unsafe_allow_html=True)


    # Injects an exact 10-pixel invisible gap on your canvas row
    st.html("<div style='height: 10px;'></div>")


    # 1. Ingest Zone 2 Master Datasets
    npm_baseline_df = load_portfolio_data("SET-3 Mart-5 1.1 NPM.csv")
    npm_optimized_df = load_portfolio_data("SET-3 Mart-5 1.2 Optimized NPM.csv")
    repricing_df = load_portfolio_data("SET-3 Mart-5 1.3 Re-pricing Items.csv")
    


#     with prof_col_chart:
    st.write("##### 📈 Dynamic Enterprise Optimization Financial Waves")
    st.caption("Select an operational metric below to instantly contrast your baseline historical performance directly against your optimized price simulation results.")
    
    # 1. THE METRIC CONDUCTOR SLICER: Central controller for the line chart axis values
    metric_options = {
        " Total Monthly Revenue Volume": {
            "y_cols": ["Baseline Revenue", "Optimized Revenue"],
            "y_label": "Total Cash Inflow Volume ($ CAD)",
            "tick_fmt": "$%d",
            "hover_fmt": "$%{y:,.2f}"
        },
        
        " Net Monthly Profit / Loss Flow": {
            "y_cols": ["Baseline Net Profit", "Optimized Net Profit"],
            "y_label": "Net Returns Flow ($ CAD)",
            "tick_fmt": "$%d",
            "hover_fmt": "$%{y:,.2f}"
        },
        
        " Net Profit Margin (NPM) Ratio": {
            "y_cols": ["Baseline NPM", "Optimized NPM"],
            "y_label": "Net Margin Efficiency Ratio",
            "tick_fmt": ".0%",
            "hover_fmt": "%{y:.2%}"
        }
    }
    
    selected_metric_label = st.selectbox(
        "Select Enterprise Metric Duo to Contrast:",
        options=list(metric_options.keys()),
        key="sb_zone2_financial_metric"
    )
    
    # Fetch the active blueprint config dictionary based on user selection
    cfg = metric_options[selected_metric_label]
    
    
    # 2. PRE-COMPILING THE DATA MARRY: Join and normalize columns with explicit tracking names
    
    m5_1_clean = npm_baseline_df[[
        '_year_month', 'total_revenue_monthly', 'net_monthly_profit', 'net_profit_margin_over_time'
    ]].rename(columns={
        'total_revenue_monthly': 'Baseline Revenue',
        'net_monthly_profit': 'Baseline Net Profit',
        'net_profit_margin_over_time': 'Baseline NPM'
    })
    
    m5_2_clean = npm_optimized_df[[
        '_year_month', 'total_revenue_monthly', 'net_monthly_profit', 'net_profit_margin_over_time'
    ]].rename(columns={
        'total_revenue_monthly': 'Optimized Revenue',
        'net_monthly_profit': 'Optimized Net Profit',
        'net_profit_margin_over_time': 'Optimized NPM'
    })
    
    merged_financial_waves = pd.merge(m5_1_clean, m5_2_clean, on='_year_month', how='inner')
    
    
    
    # 3. RENDER THE CONTRAST CHART: Points data dynamically to the configuration map values
    
    fig_financials = px.line(
        merged_financial_waves,
        x='_year_month',
        y=cfg["y_cols"],
        markers=True,
        
        # Explicitly forces Baseline curves to flash warning Red, and Optimized curves to flash healthy Green
        color_discrete_map={
            cfg["y_cols"][0]: '#e74c3c',
            cfg["y_cols"][1]: '#2ece7a'},

#         color_discrete_map={
#             'Baseline Revenue': '#e74c3c', 'Optimized Revenue': '#2ece7a',
#             'Baseline Net Profit': '#e74c3c', 'Optimized Net Profit': '#2ece7a',
#             'Baseline NPM': '#e74c3c', 'Optimized NPM': '#2ece7a'
#         },
        
        labels={'_year_month': 'Reporting Months', 'value': cfg["y_label"]}
    )
    
    
    # Apply dynamic formatting directly inside the active hover card tooltip layout:
    
    fig_financials.update_traces(hovertemplate=f"<b>Month:</b> %{{x}}<br><b>Value:</b> {cfg['hover_fmt']}<extra></extra>")
    
    fig_financials.update_layout(
        margin=dict(l=10, r=10, t=10, b=10),
        height=260, # Fits alongside your neighboring catalog data grid perfectly
        legend=dict(
            title=None,
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right", x=1),
        
        xaxis=dict(gridcolor='rgba(0,0,0,0.05)'),
        
        # AUTOMATED AXIS CONSTRAINT: Changes format type based on the dictionary configuration properties
        yaxis=dict(gridcolor='rgba(0,0,0,0.05)', tickformat=cfg["tick_fmt"]) 
    )
    
    st.plotly_chart(fig_financials, use_container_width=True)





    # -------------------------------------------------------------------------
    # ZONE 2 ROW 2: THE RE-PRICING PORTFOLIO LINE CHART
    # -------------------------------------------------------------------------
    
    st.write("##### 🏷️ Catalogue Re-Pricing Curve")
    st.caption("Visual catalogue map comparing original item base listings against newly optimized pricing tiers designed to force positive corporate margins.")
    
    # 1. Prepare data variables for multi-trace plotting mapping
    # Clean up tracking column names for clear executive legend reading layout
    
    repricing_plot_df = repricing_df.rename(columns={
        'item_price': 'Original Price',
        'new_item_price': 'Optimized Price'
    })
    
    
    # Ensure items sort cleanly by product ID to form an orderly graph sequence step
    repricing_plot_df = repricing_plot_df.sort_values(by='item_id')
    
    
    # 2. Render the full-width portfolio comparison line visualization
    fig_pricing = px.line(
        repricing_plot_df,
        x='item_id',
        y=['Original Price', 'Optimized Price'],
        markers=True,
        # Gray for baseline status, Premium Amber Orange for optimized price lift targets
        color_discrete_map={'Original Price': '#7f8c8d', 'Optimized Price': '#e67e22'},
        labels={'item_id': 'Product Catalogue Code', 'value': 'Menu Items Retail Cost ($ CAD)'}
    )
    
    
    # 3. Add custom hover data arrays to pass menu item names seamlessly into tooltips
    fig_pricing.update_traces(
        hovertemplate="<b>Product Code:</b> %{x}<br><b>Item Identity:</b> %{customdata}<br><b>Retail Price:</b> $%{y:.2f}<extra></extra>",
        customdata=repricing_plot_df['item_name']
    )
    
    
    fig_pricing.update_layout(
        margin=dict(l=10, r=10, t=10, b=10),
        height=320,
        legend=dict(title=None, orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        xaxis=dict(gridcolor='rgba(0,0,0,0.05)', type='category'), # 'category' prevents spacing gaps between product IDs
        yaxis=dict(gridcolor='rgba(0,0,0,0.05)', tickprefix="$", tickformat=".2f")
    )
    
    
    st.plotly_chart(fig_pricing, use_container_width=True)
    
    st.markdown("---")





    # =========================================================================
    # ZONE 3: ADVANCED PROFIT OPTIMIZATION ANALYSIS (aligned charts)
    # =========================================================================
   
   
   
    st.markdown(
        "<h3 style='text-align: center;'>💎 Zone 3: Enterprise Profit Protection Registry & Scenario Rescue Modeling</h3>",
        unsafe_allow_html=True
    )
    
    st.caption("Advanced Relational Ledger: Factors the labor costs down to the item level to expose hidden operational deficits and model recovery scenarios.")


    # Injects an exact 15-pixel invisible gap on your canvas row
    st.html("<div style='height: 10px;'></div>")


    with st.container(border=True):

        # 1. Ingest datasets and pre-sort by true net profit value
        scenarios_df = load_portfolio_data("SET-3 Mart-5 2 Pareto Analysis with Scenarios.csv").copy()
        cohort_val_df = load_portfolio_data("SET-3 Mart-5 3.1 Value Accumulation Cohort.csv")
        scenarios_sorted_df = scenarios_df.sort_values(by='net_profit', ascending=True)


        # -------------------------------------------------------------------------
        # LAYOUT ROW 1: CONTROLS, TITLES, & METRIC CONFIGURATIONS
        # -------------------------------------------------------------------------
        
        col_text_left, col_text_right = st.columns(2)

        with col_text_left:
            st.write("##### 🟥 Baseline Profit Realities (Burdened with Labor Wages)")
            st.caption("Exposes true net margins. Items dipping below the $0 baseline represent menu products actively operating at a financial deficit.")

        with col_text_right:
            st.write("##### 🟩 Algorithmic Price Optimization Simulation Lift")
            
            sc_map = {
                "🚀 Scenario 1: Loss-Item Break-Even Stabilization": "sc1_new_net_profit",
                "📈 Scenario 2: Mid-Tier Structural Margin Lift": "sc2_new_net_profit",
                "💎 Scenario 3: Maximum Wallet-Share Yield Optimization": "sc3_new_net_profit"
            }
            
            selected_sc_label = st.selectbox(
                "Select Prescriptive Price Optimization Target:",
                options=list(sc_map.keys()),
                key="sb_zone3_scenarios",
                label_visibility="collapsed" # Hides the redundant label text to save vertical pixels
            )
            st.caption("Simulates your prescriptive algorithms shifting menu retail values upward to rescue fragile products from deficit territory.")
            
        active_sc_column = sc_map[selected_sc_label]



        # -------------------------------------------------------------------------
        # LAYOUT ROW 2: THE ALIGNED GRAPH SUITE ROW
        # -------------------------------------------------------------------------
        
        
        col_chart_left, col_chart_right = st.columns(2)

        with col_chart_left:
            fig_reality = px.bar(
                scenarios_sorted_df, x='net_profit', y='item_id', orientation='h',
                color='net_profit', color_continuous_scale=['#e74c3c', '#2ece7a'], color_continuous_midpoint=0.0,
                labels={'net_profit': 'True Annual Net Profit ($ CAD)', 'item_id': 'Product Code'},
                
                # RANGE MATCH: Locks the horizontal boundaries
                range_x=[-4000, 16000]
            )
            
            
            fig_reality.update_traces(hovertemplate="<b>Product:</b> %{y}<br><b>Burdened Profit:</b> $%{x:,.2f}<extra></extra>")
            fig_reality.update_layout(
                margin=dict(l=10, r=10, t=0, b=10), # Set top margin to 0 for tight alignment
                coloraxis_showscale=False, height=360, 
                yaxis=dict(title=None, type='category', categoryorder='array', categoryarray=scenarios_sorted_df['item_id'])
            )
            st.plotly_chart(fig_reality, use_container_width=True)


        with col_chart_right:
            fig_rescue = px.bar(
                scenarios_sorted_df, x=active_sc_column, y='item_id', orientation='h',
                color=active_sc_column, color_continuous_scale=['#e74c3c', '#2ece7a'], color_continuous_midpoint=0.0,
                labels={active_sc_column: 'Projected Annual Net Profit ($ CAD)', 'item_id': 'Product Code'},
                
                # RANGE MATCH: Locks the horizontal boundaries
                range_x=[-4000, 16000]
            )
            
            
            fig_rescue.update_traces(hovertemplate="<b>Product:</b> %{y}<br><b>Optimized Profit:</b> $%{x:,.2f}<extra></extra>")
            fig_rescue.update_layout(
                margin=dict(l=10, r=10, t=0, b=10), # Set top margin to 0 for tight alignment
                coloraxis_showscale=False, height=360, 
                yaxis=dict(title=None, type='category', categoryorder='array', categoryarray=scenarios_sorted_df['item_id'])
            )
            st.plotly_chart(fig_rescue, use_container_width=True)


        # -------------------------------------------------------------------------
        # LAYOUT ROW 3:  LIVE METRIC SCOREBOARD CARDS (NEW ADDITION)
        # -------------------------------------------------------------------------

        # Calculate aggregate mathematical sums dynamically based on active rows in memory
        total_baseline_net = float(scenarios_sorted_df['net_profit'].sum())
        total_projected_net = float(scenarios_sorted_df[active_sc_column].sum())
        
        # Format calculations into professional rounded "K" strings at 2 decimals
        fmt_baseline_k = f"${total_baseline_net / 1000:.2f} K"
        fmt_projected_k = f"${total_projected_net / 1000:.2f} K"
        
        # Calculate the absolute growth lift difference delta
        net_profit_lift_delta = total_projected_net - total_baseline_net
        fmt_lift_delta_k = f"${net_profit_lift_delta / 1000:.2f} K Lift Generated"



        # Establish a fresh horizontal layout row for your KPI cards
        col_kpi_left, col_kpi_right = st.columns(2)
            
    #     Centre Aligning using Markdown and HTML:

        with col_kpi_left:
            st.markdown(
                f"""
                <div style="text-align: left;">
                    <p style="margin: 0; font-size: 20px;">
                        Total Network True Baseline Net Profit: 
                        <strong style="color: #e74c3c; font-size: 24px;">{fmt_baseline_k}</strong>
                    </p>
                </div>
                """,
                unsafe_allow_html=True
            )



        with col_kpi_right:
            st.markdown(
                f"""
                <div style="text-align: left;">
                    <p style="margin: 0; font-size: 20px;">
                    Total Projected Simulated Net Yield: 
                        <strong style="color: #2ece7a; font-size: 24px;">{fmt_projected_k}</strong>
                    </p>
                    <span style="
                        background-color: rgba(46, 204, 113, 0.12);
                        color: #2ece7a;
                        padding: 1px 16px;
                        border-radius: 8px;
                        font-size: 15px;
                        display: inline-block;
                        margin-top: 4px;">
                        ↑ {fmt_lift_delta_k}
                    </span >
                </div>
                """,
                unsafe_allow_html=True
            )

            
        # Inject a tiny pixel spacer before your charts draw
        st.html("<div style='height: 10px;'></div>")







    # 3. Pareto Chart

    # Injects an exact 15-pixel invisible gap on your canvas row
    st.html("<div style='height: 10px;'></div>")


    # 1. Ingest Zone 3 Datasets from Portfolio Bridge
    pareto_df = load_portfolio_data("SET-3 Mart-5 2 Pareto Analysis.csv")
    elasticity_df = load_portfolio_data("SET-3 Mart-5 4.csv")    
    
    col_left, col_right = st.columns(2)
   
    with col_left:

        st.write("##### Cumulative Annual Profit Pareto Curve (Top 80% Driver Identification)")
        
        # Sort items strictly by cumulative percentage to draw a pristine Pareto trace line
        pareto_sorted = pareto_df.sort_values(by='perc', ascending=True)
        
        # Build a visual line-and-marker chart mapping revenue volume concentration
        fig_pareto = px.line(
            pareto_sorted,
            x='item_id',
            y='perc',
            markers=True,
            color_discrete_sequence=['#f39c12'], # Industrial Amber Orange
            labels={'item_id': 'Product Code', 'perc': 'Cumulative Share of Wallet'}
        )
        
        # Add a subtle background horizontal target guide line resting exactly at the 80% boundary
        fig_pareto.add_hline(y=0.8, line_dash="dash", line_color="#e74c3c", annotation_text="80% Enterprise Profit Threshold Line")
        
        fig_pareto.update_traces(
            hovertemplate="<b>Product:</b> %{x}<br><b>Annual Profit:</b> $%{customdata:,.2f}<br><b>Cumulative Share:</b> %{y:.2%}<extra></extra>",
            customdata=pareto_sorted['annual_net_profit']
        )
        fig_pareto.update_layout(
            margin=dict(l=10, r=10, t=10, b=10),
            height=320,
            xaxis=dict(gridcolor='rgba(0,0,0,0.05)'),
            yaxis=dict(gridcolor='rgba(0,0,0,0.05)', tickformat=".0%")
        )
        st.plotly_chart(fig_pareto, use_container_width=True)




    with col_right:

        st.write("##### Profit Elasticity: 10% Promotional Campaign Discount Shocks")
        st.caption("Advanced operational stress-test: Directly contrasts true baseline net yields against post-discount profits to isolate margin degradation.")
        
        # 1. MASTER DATA COMPOSER LAYER
        # Sort strictly by the variance percentage so your most fragile items appear first
        elasticity_sorted = elasticity_df.sort_values(by='profit_sensitivity_variance_pct', ascending=True).copy()
        
        # Create a combined identifier column (Item ID + Name) to prevent X-axis collision if names repeat
        elasticity_sorted['item_display'] = elasticity_sorted['item_id'] + " - " + elasticity_sorted['item_name']
        
        # Clean up column tracking names so they map beautifully to your chart legend layout
        elasticity_plot_df = elasticity_sorted.rename(columns={
            'baseline_true_net_profit': 'Baseline Net Profit',
            'profit_after_10pct_discount': 'Post-Discount Profit'
        })
        
        # 2. RENDER THE MULTI-LINE CONTRAST CHART
        fig_elasticity = px.line(
            elasticity_plot_df,
#             x='item_display',
            x='item_id',
            y=['Baseline Net Profit', 'Post-Discount Profit'],
            markers=True,
            # Cool corporate Charcoal Gray for baseline, Alert Purple for the discount drop
            color_discrete_map={'Baseline Net Profit': '#34495e', 'Post-Discount Profit': '#9b59b6'},
            labels={'item_display': 'Menu Item Inventory Portfolio', 'value': 'Net Profit Yield ($ CAD)'}
        )
        
        # 3. HOVER MEMORY INTEGRATION: Pass your percentage column into customdata memory
        fig_elasticity.update_traces(
            hovertemplate=(
#                 "<b>Menu Item:</b> %{x}<br>"
                "<b>Menu Item:</b> %{customdata[1]}<br>"
                "<b>Net Dollar Profit:</b> $%{y:,.2f}<br>"
                "<b>Variance Impact Drop:</b> %{customdata[0]:.1f}%<extra></extra>"
            ),
            customdata=elasticity_plot_df[['profit_sensitivity_variance_pct', 'item_display']]
        )
        
        # 4. ENFORCE SYMMETRICAL GRAPH VISUALS
        fig_elasticity.update_layout(
            margin=dict(l=10, r=10, t=10, b=10),
            height=360, # Perfectly aligns bounding grids with neighboring charts
            legend=dict(title=None, orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
            xaxis=dict(gridcolor='rgba(0,0,0,0.05)', type='category', tickangle=45),
            yaxis=dict(gridcolor='rgba(0,0,0,0.05)', tickprefix="$", tickformat=",")
        )
        
        
        st.plotly_chart(fig_elasticity, use_container_width=True)



    st.markdown("---")




    # =========================================================================
    # ZONE 4: CUSTOMER RETENTION & DISCOUNT SENSITIVITY MATRIX (THE FINALE)
    # =========================================================================
 
 
 
 
 
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>👥 Zone 4: User Retention and Customer Lifetime Value Heatmaps</h3>", 
        unsafe_allow_html=True
    )
    
    
    # Injects an exact 15-pixel invisible gap on your canvas row
    st.html("<div style='height: 10px;'></div>")
 

    # 1. Ingest Zone 4 Datasets from Portfolio Bridge
    df_ret = load_portfolio_data("SET-3 Mart-5 3.2 USER RETENTION HEATMAP.csv").copy()
    df_ltv = load_portfolio_data("SET-3 Mart-5 3.1 Value Accumulation Cohort.csv").copy()
    
    
    # THE TRIM FIX for "df_ret": Cut off everything after March 2024
    # This drops all the trailing 0-acquisition months while keeping the full historical rows intact:

    ## FIX: Use pd.to_datetime and reference the correct df_ltv column
    df_ret['date_parsed'] = pd.to_datetime(df_ret['acquisition_cohort'], format='%b-%y')
    df_ret = df_ret.set_index('date_parsed')

    ## Trim:
    df_ret = df_ret.loc[:'2024-03-01']
    df_ret = df_ret.reset_index(drop=True)   
    
    
    
    # THE TRIM FIX for "df_ltv": Cut off everything after March 2024
    # This drops all the trailing 0-acquisition months while keeping the full historical rows intact:

    ## FIX: Use pd.to_datetime and reference the correct df_ltv column
    df_ltv['date_parsed'] = pd.to_datetime(df_ltv['acquisition_cohort'], format='%b-%y')
    df_ltv = df_ltv.set_index('date_parsed')

    ## Trim:
    df_ltv = df_ltv.loc[:'2024-03-01']
    df_ltv = df_ltv.reset_index(drop=True)



    # -------------------------------------------------------------------------
    # ROW 1: USER ACQUISITION & RETENTION SNAPSHOTS
    # -------------------------------------------------------------------------


    with st.container(border=True):

        st.markdown(
            "<h4 style='text-align: center;'>🔄 User Retention Analytics</h4>", 
            unsafe_allow_html=True
        )
        

        ret_col1, ret_col2 = st.columns(2)
        
        
        
        with ret_col1:
            
            st.markdown(
                "<h5 style='text-align: center;'>Retention Headcount (Snapshots)</h5>", 
                unsafe_allow_html=True
            )      
            
            
            df_ret_vol = df_ret.set_index('acquisition_cohort')[['new_customers', 'cust_retained_m12', 'cust_retained_m24']]
            
            
            fig_ret_vol = px.imshow(
                df_ret_vol.values,
                x=['Acquisitions (M0)', 'Retained (M12)', 'Retained (M24)'],
                y=df_ret_vol.index,
                labels=dict(x="Timeline", y="Cohort Month", color="Customers"),
                color_continuous_scale="Blues",
                text_auto=True,
                aspect="auto"
            )
            
            
            fig_ret_vol.update_layout(
                yaxis=dict(type='category'),
                coloraxis_showscale=True,  # <-- CHANGE THIS TO TRUE
                margin=dict(t=10, b=10, l=10, r=10))
    
    
            st.plotly_chart(fig_ret_vol, use_container_width=True)



        with ret_col2:
            
            st.markdown(
                "<h5 style='text-align: center;'>Retention Performance Rates</h5>", 
                unsafe_allow_html=True
            ) 
            
            
            # 1. Isolate the rate columns
            df_ret_rate = df_ret.set_index('acquisition_cohort')[['year_2_retention_percentage', 'year_3_retention_percentage']]
            
            
            # 2. CRITICAL FIX: Divide by 100 so Plotly scales the color maps and text logic properly
            df_ret_rate_decimals = df_ret_rate / 100.0


            # Clean display labels for the timeline axes
            rate_cols = ['Year 2 Rate (M12)', 'Year 3 Rate (M24)']
            
            
            # 3. Re-render the Interactive Percentage Heatmap 
            fig_ret_rate = px.imshow(
                df_ret_rate_decimals.values,
                x=rate_cols,
                y=df_ret_rate_decimals.index,
                labels=dict(x="Timeline", y="Cohort Month", color="Rate %"),
                color_continuous_scale="YlGnBu",
                text_auto=".1%",   # Tells Plotly to automatically display values with a % symbol
                aspect="auto",
                zmin=0.0,          # Scale matches decimal boundaries (0% to 100%)
                zmax=1.0           
            )
            
            # 4. Apply clean layout styling and ensure contrast formatting
            fig_ret_rate.update_layout(
                yaxis=dict(type='category'), 
                coloraxis_showscale=True, 
                margin=dict(t=10, b=10, l=10, r=10)
            )
            
            st.plotly_chart(fig_ret_rate, use_container_width=True)


 

    # -------------------------------------------------------------------------
    # ROW 2: LIFETIME VALUE (LTV) CUMULATIVE REVENUE
    # -------------------------------------------------------------------------


    with st.container(border=True):


        st.markdown(
            "<h4 style='text-align: center;'>💰 Customer Lifetime Value (LTV) Performance</h4>", 
            unsafe_allow_html=True
        )   
        
        
        ltv_col1, ltv_col2 = st.columns(2)


        with ltv_col1:
            
            st.markdown(
                "<h5 style='text-align: center;'>Cumulative Cohort Gross Revenue</h5>", 
                unsafe_allow_html=True
            )        
            
            
            df_ltv_tot = df_ltv.set_index('acquisition_cohort')[['ltv_m0', 'cumulative_ltv_m12', 'cumulative_ltv_m24']]
            
            
            # 1. Format to thousands abbreviated shorthand (e.g., "$28k" instead of "$28,117") 
            # This reduces character length by 60%, making it fit perfectly inside tight columns!
            fig_ltv_tot = px.imshow(
                df_ltv_tot.values,
                x=['Month 0 Revenue', 'Cumulative M12', 'Cumulative M24'],
                y=df_ltv_tot.index,
                labels=dict(x="Timeline", y="Cohort Month", color="Total Cash"),
                color_continuous_scale="Purples",
                text_auto="$.2s", # <-- FIX: The '.2s' engine turns 28117 into $28k automatically
                aspect="auto"
            )


            fig_ltv_tot.update_layout(
                yaxis=dict(type='category'), 
                coloraxis_showscale=True, # Shows the volume color map legend
                margin=dict(t=10, b=10, l=10, r=10)
            )
            
            
            st.plotly_chart(fig_ltv_tot, use_container_width=True)



        with ltv_col2:
            
            st.markdown(
                "<h5 style='text-align: center;'>Cumulative Average LTV per User</h5>", 
                unsafe_allow_html=True
            )            
            
            
            df_ltv_avg = df_ltv.set_index('acquisition_cohort')[['avg_m0', 'cumulative_avg_m12', 'cumulative_avg_m24']]
            
            
            # 2. FIX: Format with a clean currency anchor directly inside text_auto 
            # instead of wrapping it in an external texttemplate string function.
            fig_ltv_avg = px.imshow(
                df_ltv_avg.values,
                x=['Initial Spend (M0)', 'Avg Cumulative M12', 'Avg Cumulative M24'],
                y=df_ltv_avg.index,
                labels=dict(x="Timeline", y="Cohort Month", color="User Value"),
                color_continuous_scale="Reds",
                text_auto="$.1f", # <-- FIX: Pulls data accurately and prints clean text like $107.3
                aspect="auto"
            )
            
            
            fig_ltv_avg.update_layout(
                yaxis=dict(type='category'), 
                coloraxis_showscale=True, 
                margin=dict(t=10, b=10, l=10, r=10)
            )
            
            
            st.plotly_chart(fig_ltv_avg, use_container_width=True)
        
            














