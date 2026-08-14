

import streamlit as st
import plotly.express as px
import pandas as pd  # <-- Add this exact line right here!

def render_tab_2(load_portfolio_data):
    """Encapsulates all visualization, filtering, and risk math for Tab 2."""
    
    # 1. Data Ingestion Phase

    risk_now_df = load_portfolio_data("SET-3 Mart-2 4.1 Ingredients at Risk.csv")
    q1_df = load_portfolio_data("SET-2 query 1.csv")
    q2_df = load_portfolio_data("SET-2 query 2.csv")
    
    # Ingest Zone 3 Datasets from GitHub Bridge
    q3_df = load_portfolio_data("SET-2 query 3.csv")
    mart1_3_df = load_portfolio_data("SET-3 Mart-1 3.csv")
    
    # Ingest Zone 4 Datasets
    m1_2_df = load_portfolio_data("SET-3 Mart-1 2.csv")
    m2_42_df = load_portfolio_data("SET-3 Mart-2 4.2 Historical Risk Score.csv")

    
    # ==============================================================================
    # ZONE 1:  LOCALIZED MATERIAL RISK ENGINE (SET-3 Mart-2 4.1 Ingredients at Risk)
    # ==============================================================================

    # LOCALIZED MATERIAL RISK ENGINE (With Master "Select All" Override)

#     st.write("### Current Material Operational Risk Registry")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>Current Material Operational Risk Registry</h3>", 
        unsafe_allow_html=True
    )
    
    # 1. Pull distinct values and prepend a master "Show All" option string
    distinct_flags = ["Show All Risk Profiles"] + sorted(risk_now_df['critical_attention_flag'].unique())

    # 2. Render the interactive dropdown selector
    selected_flag = st.selectbox(
        "Isolate by Operational Urgency Status:",
        options=distinct_flags,
        index=0
    )
    
    # 3. Apply conditional routing: bypass if master is selected, else isolate row values
    if selected_flag == "Show All Risk Profiles":
        filtered_risk_now = risk_now_df
    else:
        filtered_risk_now = risk_now_df[risk_now_df['critical_attention_flag'] == selected_flag]
    
    
    # 4. Render the styled interactive database grid
    st.dataframe(
        
        filtered_risk_now,
        
        column_config={
            "month_week": st.column_config.TextColumn("Operational Period Log"),
            "ing_id": st.column_config.TextColumn("Ingredient Code"),
            "ing_name": st.column_config.TextColumn("Material Name"),
            "closing_stock": st.column_config.NumberColumn("Warehouse Balance (Units)", format="%d"),
            "days_without_replishment": st.column_config.NumberColumn("Days Deficit Traced", format="%d"),
            "critical_attention_flag": st.column_config.TextColumn("Active Risk Status Profile")
        },
        
        use_container_width=True,
        hide_index=True
    )
    
    st.markdown("---")




    # ====================================================================
    # ZONE 2: MATERIAL CONSUMPTION VS. PROCUREMENT DRAIN
    # ====================================================================
    
    
#     st.write("### Material Consumption Volume vs. Procurement Financial Drain")

    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>Material Consumption Volume vs. Procurement Financial Drain</h3>", 
        unsafe_allow_html=True
    )
    
    # Establish a side-by-side horizontal canvas split
    col_vol, col_cost = st.columns(2)
    
    with col_vol:
        st.write("##### Top 10 High-Volume Ingredients Consumed")
        
        # Aggregate raw rows by ingredient to find the macro consumers, sort, and isolate top 10
        vol_agg = q1_df.groupby('ing_id', as_index=False)['total_quantity_consumed'].sum()
        df_vol_sorted = vol_agg.sort_values(by='total_quantity_consumed', ascending=True).tail(10)
        
        fig_vol = px.bar(
            df_vol_sorted,
            x='total_quantity_consumed',
            y='ing_id',
            orientation='h',
            color='total_quantity_consumed',
            color_continuous_scale='Greens',
            labels={'total_quantity_consumed': 'Total Units Used', 'ing_id': 'Ingredient ID'}
        )
        
        # Apply custom interactive hover tooltips with raw integer mapping
        fig_vol.update_traces(
            hovertemplate="<b>Ingredient:</b> %{y}<br><b>Volume:</b> %{x:,} Units<extra></extra>"
        )
        
        fig_vol.update_layout(margin=dict(l=20, r=20, t=20, b=20), coloraxis_showscale=False)
        
        st.plotly_chart(fig_vol, use_container_width=True)
        
        
    with col_cost:
        st.write("##### Top 10 Financial Cost Drivers (Procurement Capital Drain)")
        
        # Aggregate procurement financial cost columns by ingredient, sort, and isolate top 10
        cost_agg = q2_df.groupby('ing_id', as_index=False)['procurement_demand_cost'].sum()
        df_cost_sorted = cost_agg.sort_values(by='procurement_demand_cost', ascending=True).tail(10)
        
        fig_cost = px.bar(
            df_cost_sorted,
            x='procurement_demand_cost',
            y='ing_id',
            orientation='h',
            color='procurement_demand_cost',
            color_continuous_scale='Oranges',
            labels={'procurement_demand_cost': 'Total Capital Spend ($)', 'ing_id': 'Ingredient ID'}
        )
        
        # Apply custom interactive hover tooltips with accounting currency mapping
        fig_cost.update_traces(
            hovertemplate="<b>Ingredient:</b> %{y}<br><b>Capital Drain:</b> $%{x:,.2f}<extra></extra>"
        )
        fig_cost.update_layout(margin=dict(l=20, r=20, t=20, b=20), coloraxis_showscale=False)
        
        st.plotly_chart(fig_cost, use_container_width=True)
        
    st.markdown("---")
    
    
    

    # =========================================================================
    # ZONE 3: PRODUCT PROFITABILITY & STOCK REPLENISHMENT ENGINES
    # =========================================================================


#     st.write("### 🧮 Product Formulation Cost Lookups & Impending Reorder Alerts")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>🧮 Product Formulation Cost Lookups & Impending Reorder Alerts</h3>", 
        unsafe_allow_html=True
    )

    
    # 2. Allocate an equal 50/50 vertical canvas split layout
    col_lookup, col_alerts = st.columns(2)
    
    with col_lookup:
        st.write("##### 🍕 Product Formulation Cost Matrix Explorer")
        
        # Create small internal columns to put your 2 slicers side-by-side
        slicer_a, slicer_b = st.columns(2)
        
        with slicer_a:
            distinct_cats = sorted(q3_df['item_cat'].unique())
            selected_cats = st.multiselect(
                "Filter by Category:",
                options=distinct_cats,
                default=distinct_cats
            )
            
        with slicer_b:
            # Sync pool to keep SKUs relevant to selected categories
            sku_pool = q3_df[q3_df['item_cat'].isin(selected_cats)]
            distinct_skus = sorted(sku_pool['sku'].unique())
            selected_skus = st.multiselect(
                "Search / Isolate SKUs:",
                options=distinct_skus,
                default=distinct_skus[:2]
            )
        
        # Apply both vector slicing conditions to table
        filtered_q3 = q3_df[
            (q3_df['item_cat'].isin(selected_cats)) & 
            (q3_df['sku'].isin(selected_skus))
        ]

        # AGGREGATION MATRIX: Group by all text metadata and sum the fractional costs
        grouped_q3 = filtered_q3.groupby(
            ['item_id', 'sku', 'item_cat'], 
            as_index=False
        )['row_fract_cost'].sum()
        
        # Reorder columns to drop raw item_id and keep presentation clean
        reordered_q3 = grouped_q3[['item_cat', 'sku', 'row_fract_cost']]
        
        st.dataframe(
            reordered_q3,
            column_config={
                "item_cat": st.column_config.TextColumn("Menu Category Name"),
                "sku": st.column_config.TextColumn("Product SKU"),
                "row_fract_cost": st.column_config.NumberColumn("Item Procurement Cost ($)", format="$%,.2f")
            },
            use_container_width=True,
            hide_index=True
        )
        
    with col_alerts:
        st.write("##### ⚠️ Operational Buffer Alerts (Stock Levels Between 60% & 80%)")
        st.caption("Monitors warehouse ingredients entering the pre-crisis window requiring order placement prep.")

        # 1. Filter out the noise to only keep rows where a reorder check is active
        active_alerts_df = mart1_3_df[mart1_3_df['stock_percent_between60_80'] == "CHECK for reorder"].copy()

        # 2. TIMELINE CONVERSION: Ensure snapshot_date is parsed as a true datetime object for accurate sorting
        active_alerts_df['snapshot_date'] = pd.to_datetime(active_alerts_df['snapshot_date'])
        
        # 3. CHRONOLOGICAL SORT: Sort by date ascendingly so the latest dates sit at the bottom of the array
        sorted_alerts_df = active_alerts_df.sort_values(by='snapshot_date', ascending=True)
        
        # 4. LATEST DEDUPLICATION: Keep only the final (latest) chronological record for each unique ingredient
        latest_alerts_df = sorted_alerts_df.drop_duplicates(subset=['ing_id'], keep='last').copy()
        
        # Convert date back to a clean string format for executive presentation
        latest_alerts_df['snapshot_date'] = latest_alerts_df['snapshot_date'].dt.strftime('%Y-%m-%d')



        st.dataframe(
            latest_alerts_df,
            column_config={
                "snapshot_date": st.column_config.TextColumn("Log Date"),
                "ing_id": st.column_config.TextColumn("Material Code"),
                "closing_stock": st.column_config.NumberColumn("Warehouse Balance", format="%d"),
                "pending_order": st.column_config.TextColumn("Pipeline Order Active (Y/N)"),
                "stock_percent_between60_80": st.column_config.TextColumn("Trigger Condition Flag")
            },
            use_container_width=True,
            hide_index=True,
            height=320 
        )
        
    st.markdown("---")





    # =========================================================================
    # ZONE 4: INVENTORY DEPLETION & HISTORICAL RISK VELOCITY
    # =========================================================================

#     st.write("### 📈 Macro Material Depletion Speeds & Historical Breach Frequencies")

    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>📈 Macro Material Depletion Speeds & Historical Breach Frequencies</h3>", 
        unsafe_allow_html=True
    )
    
    
    # Establish a balanced side-by-side horizontal visualization column split
    chart_col_a, chart_col_b = st.columns(2)

    # Ver-2
    with chart_col_a:
        st.write("##### Material Depletion Velocity Trends (Raw Volatility)")
        
        m1_2_df['snapshot_date'] = pd.to_datetime(m1_2_df['snapshot_date'])
        available_years = sorted(m1_2_df['snapshot_date'].dt.year.unique())
        
        # 1. Row Split for side-by-side temporal slicers
        slicer_y, slicer_m = st.columns(2)
        
        with slicer_y:
            selected_year = st.selectbox(
                "Select Year:",
                options=available_years,
                index=len(available_years)-1,
                key="zc_year")
            
        # Filter year first to populate the month dropdown with active historical logs
        yearly_df = m1_2_df[m1_2_df['snapshot_date'].dt.year == selected_year].copy()
        
        with slicer_m:
            # Extract month names ordered chronologically (January to December)
            yearly_df['month_name'] = yearly_df['snapshot_date'].dt.month_name()
            month_order = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            available_months = [m for m in month_order if m in yearly_df['month_name'].unique()]
            
            selected_month = st.selectbox(
                "Select Reporting Month:",
                options=available_months,
                index=0,
                key="zc_month")
            
        # 2. Apply the final monthly filtering vector
        monthly_filtered_df = yearly_df[yearly_df['month_name'] == selected_month].copy()
      
        # 3. THE BOTH-SIDES OVERLAY FIX: Calculate absolute distance from zero
        monthly_filtered_df['abs_velocity'] = monthly_filtered_df['depletion_velocity'].abs()
        
        # Sort descendingly so massive bars draw first, and shorter bars layer on top
        monthly_filtered_df = monthly_filtered_df.sort_values(by='abs_velocity', ascending=False)
        monthly_filtered_df['date_str'] = monthly_filtered_df['snapshot_date'].dt.strftime('%Y-%m-%d')
        
        # 4. Render your raw daily diverging barcode chart using the high-performance sliced subset
        fig_dep = px.bar(
            monthly_filtered_df,
            x='depletion_velocity',
            y='ing_id',
            orientation='h',
            color='depletion_velocity',
            color_continuous_scale=px.colors.diverging.RdYlGn_r,
            
            # Pass a list of columns to make them available in hover trace memory
            custom_data=['date_str', 'ing_id'],
            
            labels={'depletion_velocity': 'Daily Velocity Shift', 'ing_id': 'Material Code'}
        )
        
        fig_dep.update_traces(
            hovertemplate="<b>Material:</b> %{customdata[1]}<br><b>Date:</b> %{customdata[0]}<br><b>Shift:</b> %{x} units/day<extra></extra>"
        )


        # 5. FORCE OVERLAY MODE: Places bars independently over the axis without adding them together
        fig_dep.update_layout(
            margin=dict(l=20, r=20, t=20, b=20), 
            coloraxis_showscale=False,
            barmode='overlay',
            xaxis=dict(zeroline=True, zerolinewidth=2, zerolinecolor='black')
        )
        
        st.plotly_chart(fig_dep, use_container_width=True)


        
    with chart_col_b:
        st.write("##### Most Frequent Threat Offenders (Cumulative Breach Count)")
        
        # Sort data to show items that breach the safety zone the most often at the top
        df_risk_sorted = m2_42_df.sort_values(by='total_breach_count', ascending=True)
        
        fig_risk = px.bar(
            df_risk_sorted,
            x='total_breach_count',
            y='ing_name',
            orientation='h',
            color='cumulative_risk_score',
            color_continuous_scale='Purples',
            labels={'total_breach_count': 'Total Logged Breaches', 'ing_name': 'Material Name'}
        )
        fig_risk.update_traces(hovertemplate="<b>Material:</b> %{y}<br><b>Breach Count:</b> %{x} incidents<extra></extra>")
        fig_risk.update_layout(margin=dict(l=20, r=20, t=20, b=20), coloraxis_showscale=False)
        st.plotly_chart(fig_risk, use_container_width=True)
        
    st.markdown("---")




    # =========================================================================
    # ZONE 5: DEEP AUDIT & HISTORICAL VOLATILITY MATRIX (Collapsible Accordions)
    # =========================================================================
    
    
    st.write("### 🗄️ Historical Supply Chain Audits & Material Volatility Ledger")
    
    # 1. Ingest Zone 5 Core Datasets from Portfolio Bridge
    mart1_5_df = load_portfolio_data("SET-3 Mart-1 5.csv")
    mart1_6_df = load_portfolio_data("SET-3 Mart-1 6.csv")
    mart2_1_df = load_portfolio_data("SET-3 Mart-2 1.csv")
    
    # -------------------------------------------------------------------------
    # ACCORDION A: MONTHLY STOCKOUT FREQUENCY TRACKER (SET-3 Mart-1 5)
    # -------------------------------------------------------------------------
    with st.expander("📊 View Tracker A: Monthly Stockout Frequency Ledger"):
        st.write("##### Historical Incidents: Out-of-Stock Metrics by Ingredient")
        
        # Localized dropdown filter unique to this specific accordion container
        distinct_months_5 = sorted(mart1_5_df['year_month'].unique())
        selected_month_5 = st.selectbox(
            "Filter Stockout Log by Month:",
            options=distinct_months_5,
            key="sb_mart1_5" # Unique session key prevents collision with main page filters
        )
        
        # Apply localized vector filtering
        filtered_mart1_5 = mart1_5_df[mart1_5_df['year_month'] == selected_month_5]
        
        st.dataframe(
            filtered_mart1_5,
            column_config={
                "year_month": st.column_config.TextColumn("Reporting Period"),
                "ing_id": st.column_config.TextColumn("Ingredient Code"),
                "ing_name": st.column_config.TextColumn("Material Name"),
                "times_ran_out_of_stock": st.column_config.NumberColumn("Stockout Incidents", format="%d"),
                "total_days_spent_out_of_stock": st.column_config.NumberColumn("Total Days Deficit", format="%d")
            },
            use_container_width=True,
            hide_index=True
        )

    # -------------------------------------------------------------------------
    # ACCORDION B: DAYS BELOW SAFETY THRESHOLD (SET-3 Mart-1 6)
    # -------------------------------------------------------------------------
    
    with st.expander("📉 View Tracker B: Material Days Below Safety Threshold"):
        st.write("##### Exposure Log: Extended Operations Under Safe Buffer Limits")
        
        # Pull distinct calendar periods using your explicit column name variant (year-month)
        distinct_months_6 = sorted(mart1_6_df['year-month'].unique())
        selected_month_6 = st.selectbox(
            "Filter Threshold Log by Month:",
            options=distinct_months_6,
            key="sb_mart1_6"
        )
        
        filtered_mart1_6 = mart1_6_df[mart1_6_df['year-month'] == selected_month_6]
        
        st.dataframe(
            filtered_mart1_6,
            column_config={
                "year-month": st.column_config.TextColumn("Reporting Period"),
                "ing_id": st.column_config.TextColumn("Ingredient Code"),
                "ing_name": st.column_config.TextColumn("Material Name"),
                "days_below_threshold": st.column_config.NumberColumn("Days spent in Danger Zone", format="%d")
            },
            use_container_width=True,
            hide_index=True
        )



    # -------------------------------------------------------------------------
    # ACCORDION C: MACRO INVENTORY VOLATILITY INDEX MATRIX (With Donut Chart)
    # -------------------------------------------------------------------------
    
    
    with st.expander("💎 View Tracker C: Macro Inventory Volatility Index Grid"):
        st.write("##### Risk Profile: Long-Term Balance Shifting & Stability Tiers")
        
        # Allocate workspace into columns: Left for controls & ledger, Right for Donut Chart
        col_data, col_chart = st.columns([3, 2])
        
        with col_data:
            # 1. SLICER 1: Year-Month selection
            distinct_months = sorted(mart2_1_df['year-month'].unique())
            selected_month = st.selectbox("Select Reporting Month:", options=distinct_months, key="ac_month")
            
            # Step-A: Filter pool to handle cascading choice logic
            month_pool = mart2_1_df[mart2_1_df['year-month'] == selected_month]
            
            # 2. SLICER 2: Cascading Ingredient ID search filter
            distinct_ings = ["Show All Ingredients"] + sorted(month_pool['ing_id'].unique())
            selected_ing = st.selectbox("Search / Isolate Ingredient:", options=distinct_ings, key="ac_ing")
            
            # Step-B: Apply cascading filter
            if selected_ing == "Show All Ingredients":
                ing_pool = month_pool
            else:
                ing_pool = month_pool[month_pool['ing_id'] == selected_ing]
                
            # 3. SLICER 3: Existing Risk Tier Category Filter
            distinct_tiers = ["Show All Risk Tiers"] + sorted(ing_pool['risk_tier'].unique())
            selected_tier = st.selectbox("Filter Ledger by Risk Category:", options=distinct_tiers, key="ac_tier")
            
            # Step-C: Apply final data routing for the spreadsheet ledger view
            if selected_tier == "Show All Risk Tiers":
                final_ledger_df = ing_pool
            else:
                final_ledger_df = ing_pool[ing_pool['risk_tier'] == selected_tier]
        
        with col_chart:
            st.write("##### 🍩 Warehouse Risk Tier Distribution")
            
            # Calculate the counts per risk tier from our active ingredient pool
            chart_data = ing_pool.groupby('risk_tier', as_index=False).size()
            
            # Set up highly contextual color mappings matching enterprise risk standards
            color_map = {
                "Green Healthy (Rock-Solid Stability)": "#2ece7a",
                "Yellow Warning (Moderately Shifting)": "#f1c40f",
                "Red Alert (Wildly Volatile)": "#e74c3c"
            }
            
            # Build the premium donut visualization
            fig_donut = px.pie(
                chart_data,
                values='size',
                names='risk_tier',
                hole=0.5, # Defines the inner radius cutout percentage making it a donut
                color='risk_tier',
                color_discrete_map=color_map
            )
            
            # Configure clean executive tooltips and hide external legend crowding
            fig_donut.update_traces(
                textinfo='percent',
                hovertemplate="<b>Risk Tier:</b> %{label}<br><b>Ingredients:</b> %{value}<br><b>Share:</b> %{percent}<extra></extra>"
            )
            fig_donut.update_layout(
                margin=dict(l=10, r=10, t=10, b=10),
                showlegend=False, # Hides the messy side legend box
                height=260
            )
            st.plotly_chart(fig_donut, use_container_width=True)
            
    
    
        # Display the fully filtered spreadsheet ledger cleanly across the entire bottom baseline row
        st.write("##### 📑 Filtered Volatility Records Ledger")
        st.dataframe(
            final_ledger_df,
            column_config={
                "year-month": st.column_config.TextColumn("Reporting Period"),
                "ing_id": st.column_config.TextColumn("Ingredient Code"),
                "ing_name": st.column_config.TextColumn("Material Name"),
                "avg_stock": st.column_config.NumberColumn("Average Warehouse Stock", format="%.2f"),
                "stock_volatility": st.column_config.NumberColumn("Standard Deviation", format="%.2f"),
                "volatility_index": st.column_config.NumberColumn("Volatility Index Score", format="%.4f"),
                "risk_tier": st.column_config.TextColumn("Enterprise Risk Category")
            },
            use_container_width=True,
            hide_index=True
        )







