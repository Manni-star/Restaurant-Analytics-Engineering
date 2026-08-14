

import streamlit as st
import plotly.express as px
import pandas as pd

def render_tab_3(load_portfolio_data):
    """Encapsulates all visualization, filtering, and metric logic for Tab 3."""
 
 
    # Injects an exact 5-pixel invisible gap on your canvas row
    st.html("<div style='height: 5px;'></div>")
 
 
    # 1. Data Ingestion Phase

    staff_latest_df = load_portfolio_data("SET-2 query 6 Staff Cost Latest Week.csv")
    hhi_df = load_portfolio_data("SET-3 Mart-6 4.csv")
    spend_share_df = load_portfolio_data("SET-3 Mart-3 5.csv")
    switches_df = load_portfolio_data("SET-3 Mart-3 4.csv")




    # =========================================================================
    # ZONE 1: PROCUREMENT CORE METRIC WALL (THE TOP BANNER)
    # =========================================================================
    
    
    # 1. Calculate raw total cash outflow spent on wages in the active week
    raw_weekly_wages = float(staff_latest_df['weekly_wages'].sum())
    
    # REFORMATTING LOGIC: Convert the raw float into a clean, rounded 'K' string
    formatted_wages = f"${raw_weekly_wages / 1000:.1f} K"
    
    # 2. Extract the total headcount of active crew members logged this week
    total_staff_count = int(staff_latest_df['staff_id'].nunique())
    
    # 3. Extract the raw structural supplier concentration index score
    raw_hhi_score = int(hhi_df['hhi_supplier'].iloc[0])
    
    # Establish a balanced 3-column horizontal grid layout banner across the top
    kpi_col_a, kpi_col_b, kpi_col_c = st.columns(3)
    
    with kpi_col_a:
        st.metric(
            label="Active Week Labor Wages",
            value=formatted_wages,
            delta=f"Active Week Log (year-week): {staff_latest_df['year_week_id'].iloc[0]}",
            delta_color="off"
        )
        
    with kpi_col_b:
        st.metric(
            label="Active Workforce Headcount",
            value=f"{total_staff_count} Employees",
            delta="Full-Time & Part-Time Operations",
            delta_color="off"
        )
        
    with kpi_col_c:
        # Contextual status flag checking if market concentration risks are critical
        if raw_hhi_score > 2500:
            hhi_status = "⚠️ HIGH CONCENTRATION RISK"
        else:
            hhi_status = "✅ SAFE DIVERSIFICATION"
            
        st.metric(
            label="Supplier Market Concentration Index (HHI)",
            value=f"{raw_hhi_score} Points",
            delta=hhi_status,
            delta_color="inverse"
        )
        
    st.markdown("---")

    
    

    # =========================================================================
    # ZONE 2: SUPPLIER CAPACITY & PROCUREMENT DRAIN
    # =========================================================================
     
#     st.write("### 🪙 Capital Allocation Share vs. Logistical Switching Instability")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>🪙 Capital Allocation Share vs. Logistical Switching Instability</h3>", 
        unsafe_allow_html=True
    )
    
    # Injects an exact 15-pixel invisible gap on your canvas row
    st.html("<div style='height: 2px;'></div>")
    
    col_donut, col_bar = st.columns(2)
    
    with col_donut:
        st.write("##### Enterprise Procurement Spend Share dominance")
        
        # Build a premium vendor spend donut visualization layout
        fig_donut = px.pie(
            spend_share_df,
            values='supplier_spend',
            names='supplier_id',
            hole=0.5,
            color='supplier_id',
            color_discrete_sequence=px.colors.qualitative.Bold,
#             labels={'supplier_spend': 'Spend Capital ($)', 'supplier_id': 'Vendor Code'}
        )
        fig_donut.update_traces(
            textinfo='percent',
            textposition='inside', # Moves text inside the slice
            hovertemplate="<b>Vendor ID:</b> %{label}<br><b>Capital Share:</b> $%{value:,.2f}<br><b>Ratio:</b> %{percent}<extra></extra>"
        )
        fig_donut.update_layout(margin=dict(l=20, r=20, t=20, b=20), showlegend=True, height=300)
        st.plotly_chart(fig_donut, use_container_width=True)
        
        
        
    with col_bar:
        st.write("##### Mid-Tier Disruption: Material Supplier Switches by Ingredient Code")
        
        # Aggregate raw database lines to find out which items face chaotic vendor shuffling
        switches_agg = switches_df.groupby('ing_id', as_index=False)['supplier_switches'].sum()
        df_switches_sorted = switches_agg.sort_values(by='supplier_switches', ascending=True).tail(10)
        
        fig_bar = px.bar(
            df_switches_sorted,
            x='supplier_switches',
            y='ing_id',
            orientation='h',
            color='supplier_switches',
            color_continuous_scale='YlOrRd',
            labels={'supplier_switches': 'Logged Switching Events', 'ing_id': 'Material Code'}
        )
        fig_bar.update_traces(hovertemplate="<b>Material Code:</b> %{y}<br><b>Vendor Switches:</b> %{x} events<extra></extra>")
        fig_bar.update_layout(margin=dict(l=20, r=20, t=20, b=20), coloraxis_showscale=False, height=300)
        st.plotly_chart(fig_bar, use_container_width=True)
        
    st.markdown("---")




    # =========================================================================
    # ZONE 3: VENDOR RISK REGISTRY & STABILITY DESK (CENTRAL ENGINE)
    # =========================================================================
    
    
#     st.write("### 🛡️ Procurement Security Matrix & Vendor Risk Registry")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>🛡️ Procurement Security Matrix & Vendor Risk Registry</h3>", 
        unsafe_allow_html=True
    )

    
    # 1. Ingest Zone 3 and Zone 4 Datasets
    m3_1_df = load_portfolio_data("SET-3 Mart-3 1.csv")
    m3_2_df = load_portfolio_data("SET-3 Mart-3 2 Supplier Instability Score.csv")
    m1_4_df = load_portfolio_data("SET-3 Mart-1 4.csv")
    
    # 2. DATA ENGINEERING JOIN: Merge dependency metrics and risk scores in memory
    merged_vendor_df = pd.merge(
        m3_1_df, 
        m3_2_df, 
        on=['supplier_id', 'ing_id'], 
        how='inner'
    )
    
    # 3. INTERACTIVE SLICER: Central dropdown filter to cascade to all four bar charts
    distinct_suppliers = sorted(merged_vendor_df['supplier_id'].unique())
    selected_supplier = st.selectbox(
        "Isolate Target Vendor Portfolio Audit:",
        options=distinct_suppliers,
        index=0,
        key="sb_zone3_vendor"
    )
    
    # Filter the master table rows down to the chosen vendor pool
    v_pool = merged_vendor_df[merged_vendor_df['supplier_id'] == selected_supplier].copy()
    
    st.write("##### 📊 Supplier Portfolio Resource & Risk Cutouts")
    
    # INTERACTIVE DRILL-DOWN TOGGLE: Lets user unpack the 'Other' group instantly
    drill_down_active = st.checkbox(
        "🔍 Activate Drill-Down Matrix (Expand 'All Other Materials')", 
        value=False,
        key="cb_drill_down"
    )

    # Helper function to dynamically bundle smaller items into a unified row
    def apply_top5_bundling(df, target_value_column):
        if len(df) <= 5 or drill_down_active:
            # If data is small or drill-down checkbox is active, return raw sorted rows as-is
            return df.sort_values(by=target_value_column, ascending=True)
            
        # Separate the top 5 heaviest resource drivers
        df_sorted = df.sort_values(by=target_value_column, ascending=False)
        top5 = df_sorted.head(5).copy()
        others = df_sorted.tail(len(df_sorted) - 5)
        
        # Aggregate the remaining long-tail records into a single summary block
        others_summed = pd.DataFrame([{
            'ing_id': '📦 All Other Materials',
            'supplier_id': selected_supplier,
            target_value_column: others[target_value_column].sum(),
            'supplier_dependency_ratio': others['supplier_dependency_ratio'].mean(),
            'lead_time_volatility': others['lead_time_volatility'].mean(),
            'supplier_instability_score': int(others['supplier_instability_score'].mean() if len(others) > 0 else 0)
        }])
        
        # Combine back together and reverse the order for clean ascending bar rendering
        combined = pd.concat([top5, others_summed], ignore_index=True)
        return combined.sort_values(by=target_value_column, ascending=True)

    # 4. RENDER THE 2x2 HORIZONTAL BAR MATRIX GRID
    row1_col1, row1_col2 = st.columns(2)
    row2_col1, row2_col2 = st.columns(2)
    
    # Global hover definition for clean chart alignment
    custom_hover_str = (
        "<b>Value:</b> %{x:,.2f}<br>"
        "<b>Material:</b> %{y}<br>"
#         "<hr>"
        "<b>Dependency Ratio:</b> %{customdata[0]:.2f}<br>"
        "<b>Lead Time Volatility:</b> %{customdata[1]:.2f}<br>"
        "<b>Instability Score:</b> %{customdata[2]}<extra></extra>"
    )
    
    with row1_col1:
        st.write("##### 📦 Order Distribution Volume")
        df1 = apply_top5_bundling(v_pool, 'total_orders_by_supplier')
        fig1 = px.bar(df1, x='total_orders_by_supplier', y='ing_id', orientation='h',
                      color='total_orders_by_supplier', color_continuous_scale='Blues',
                      custom_data=['supplier_dependency_ratio', 'lead_time_volatility', 'supplier_instability_score'])
        fig1.update_traces(hovertemplate=custom_hover_str)
        fig1.update_layout(margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False, height=240, yaxis=dict(title=None))
        st.plotly_chart(fig1, use_container_width=True)
        
    with row1_col2:
        st.write("##### 📊 Volume Contribution Units")
        df2 = apply_top5_bundling(v_pool, 'supplier_volume')
        fig2 = px.bar(df2, x='supplier_volume', y='ing_id', orientation='h',
                      color='supplier_volume', color_continuous_scale='Greens',
                      custom_data=['supplier_dependency_ratio', 'lead_time_volatility', 'supplier_instability_score'])
        fig2.update_traces(hovertemplate=custom_hover_str)
        fig2.update_layout(margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False, height=240, yaxis=dict(title=None))
        st.plotly_chart(fig2, use_container_width=True)
        
    with row2_col1:
        st.write("##### 🚨 Material HHI Risk Index")
        df3 = apply_top5_bundling(v_pool, 'ingredient_hhi_risk_index')
        fig3 = px.bar(df3, x='ingredient_hhi_risk_index', y='ing_id', orientation='h',
                      color='ingredient_hhi_risk_index', color_continuous_scale='Oranges',
                      custom_data=['supplier_dependency_ratio', 'lead_time_volatility', 'supplier_instability_score'])
        fig3.update_traces(hovertemplate=custom_hover_str)
        fig3.update_layout(margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False, height=240, yaxis=dict(title=None))
        st.plotly_chart(fig3, use_container_width=True)
        
    with row2_col2:
        st.write("##### 🕒 Average Delivery Lead Time")
        df4 = apply_top5_bundling(v_pool, 'avg_lead_time')
        fig4 = px.bar(df4, x='avg_lead_time', y='ing_id', orientation='h',
                      color='avg_lead_time', color_continuous_scale='Purples',
                      custom_data=['supplier_dependency_ratio', 'lead_time_volatility', 'supplier_instability_score'])
        fig4.update_traces(hovertemplate=custom_hover_str)
        fig4.update_layout(margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False, height=240, yaxis=dict(title=None))
        st.plotly_chart(fig4, use_container_width=True)



    # 5. DYNAMIC DOUBLE DRILL-DOWN: Chronological Material-Level Audit Trails

    with st.expander("📑 View Detailed Chronological Audit Trail (Raw Transaction Logs)"):  
    
        st.write(f"##### 📋 Deep-Dive Historical Delivery Trail Logs for {selected_supplier}")
        
        # Isolate all historical transactions for this vendor first
        vendor_historical_trail = m1_4_df[m1_4_df['supplier_id'] == selected_supplier].copy()
        
        # CASCADING INGREDIENT FILTER: Extract unique ingredients handled by THIS vendor specifically
        vendor_active_ings = ["Show All Materials Summary"] + sorted(vendor_historical_trail['ing_id'].unique())
        
        selected_audit_ing = st.selectbox(
            "Select Specific Material to Audit Timeline Logs:",
            options=vendor_active_ings,
            index=0,
            key="sb_zone3_audit_trail_ing" # Keeps state isolated from your top quadrant filters
        )
        
        # Apply the conditional secondary vector slice
        if selected_audit_ing == "Show All Materials Summary":
            final_trail_display = vendor_historical_trail
        else:
            final_trail_display = vendor_historical_trail[vendor_historical_trail['ing_id'] == selected_audit_ing]
            
        # Sort the final display chronologically from newest order to oldest
        final_trail_display = final_trail_display.sort_values(by='order_date', ascending=False)

        # Render the highly contextual, non-repetitive operational ledger
        st.dataframe(
            final_trail_display,
            column_config={
                "supplier_id": st.column_config.TextColumn("Vendor Code"),
                "ing_id": st.column_config.TextColumn("Material Code"),
                "transaction_type": st.column_config.TextColumn("Log Type"),
                "order_date": st.column_config.TextColumn("Order Date Placed"),
                "receipt_date": st.column_config.TextColumn("Delivery Receipt Date"),
                "lead_time": st.column_config.NumberColumn("Actual Lead Time (Days)", format="%d")
            },
            use_container_width=True,
            hide_index=True,
            height=240 # Maintains high performance with built-in vertical scrollbars
        )
    
    st.markdown("---")




    # =========================================================================
    # ZONE 4: PURCHASE ORDER VOLUME BURST ANALYSIS (THE FINAL ENGINE)
    # =========================================================================
    
    
    
#     st.write("### 💥 Procurement Order Burst & Velocity Surge Analytics")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>💥 Procurement Order Burst & Velocity Surge Analytics</h3>", 
        unsafe_allow_html=True
    )  
    
    st.caption("Side-by-side diagnostic: Compares the average frequency spacing between consecutive orders against the quantity weights processed.")
    
    # 1. Ingest Zone 4 Burst Dataset from Portfolio Bridge
    burst_df = load_portfolio_data("SET-3 Mart-3 3.csv")
    
    # 2. CORE TRUTH AGGREGATION: Collapse thousands of rows to find averages per material
    burst_agg = burst_df.groupby('ing_id', as_index=False).agg({
        'order_burst_days': 'mean',
        'change_qty': 'mean'
    })
    
    # 3. TOP CONTROL ROW: Drill-down checkbox placed at the very top of Zone 4
    drill_down_active = st.checkbox(
        "🔍 Activate Drill-Down Matrix (Expand 'All Other Materials')", 
        value=False,
        key="cb_zone4_drill_down",
        help="Deactivates the default Top 10 limit to render every single available material in the warehouse portfolio."
    )
    
    # 4. SECONDARY CONTROL ROW: Multi-select search bar placed right underneath the checkbox
    distinct_ings = sorted(burst_agg['ing_id'].unique())
    selected_ings = st.multiselect(
        "Search / Isolate Material Codes for Side-by-Side Comparison:",
        options=distinct_ings,
        default=[], # Empty by default to trigger the automated fallback rules
        key="ms_zone4_ings"
    )


    # 5. DATA COMPOSER LAYER: Apply filtering, sorting, and drill-down sequencing
    if len(selected_ings) > 0:
        # If user explicitly chooses materials in the multi-select, show only those rows sorted by spacing
        filtered_charts_df = burst_agg[burst_agg['ing_id'].isin(selected_ings)].sort_values(by='order_burst_days', ascending=False)
    else:
        # Automated fallback when no specific search is active
        if drill_down_active:
            # VELOCITY FILTER: Discard any material beyond 15 days spacing when expanding rows
            filtered_charts_df = burst_agg[burst_agg['order_burst_days'] <= 15].sort_values(by='order_burst_days', ascending=False)
        else:
            # Show only the top 10 rows with the tightest turnaround cycles
            filtered_charts_df = burst_agg.sort_values(by='order_burst_days', ascending=False).tail(10)


    # 6. ALLOCATE CANVAS: Spacious 50/50 horizontal chart grid layout row
    b_col_left, b_col_right = st.columns(2)
    
    with b_col_left:
        st.write("##### 🕒 Average Days Between Orders")
        
        fig_space = px.bar(
            filtered_charts_df,
            x='order_burst_days',
            y='ing_id',
            orientation='h',
            color='order_burst_days',
            color_continuous_scale='Reds_r', # Inverted Reds: smaller values display in harsher colors
            labels={'order_burst_days': 'Mean Days Between Orders', 'ing_id': 'Material Code'}
        )
        fig_space.update_traces(hovertemplate="<b>Material:</b> %{y}<br><b>Avg Spacing:</b> %{x:.1f} days<extra></extra>")
        fig_space.update_layout(margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False, height=350, yaxis=dict(title=None))
        st.plotly_chart(fig_space, use_container_width=True)

        
    with b_col_right:
        st.write("##### 📦 Average Ordered Quantity Per PO")
        
        # Match the exact ingredient sorting sequence from the left chart so rows align perfectly
        fig_vol = px.bar(
            filtered_charts_df,
            x='change_qty',
            y='ing_id',
            orientation='h',
            color='change_qty',
            color_continuous_scale='Blues',
            labels={'change_qty': 'Mean Units Per Purchase Order', 'ing_id': 'Material Code'}
        )
        fig_vol.update_traces(hovertemplate="<b>Material:</b> %{y}<br><b>Avg Order Vol:</b> %{x:.1f} units<extra></extra>")
        fig_vol.update_layout(margin=dict(l=10, r=10, t=10, b=10), coloraxis_showscale=False, height=350, yaxis=dict(title=None))
        st.plotly_chart(fig_vol, use_container_width=True)
        
    st.markdown("---")











    