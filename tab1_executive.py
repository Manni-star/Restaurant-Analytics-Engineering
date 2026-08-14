

import streamlit as st
import plotly.express as px

def render_tab_1(load_portfolio_data):
    """Encapsulates all visualization, layout, and data-pulling operations for Tab 1."""


    # Injects an exact 5-pixel invisible gap on your canvas row
    st.html("<div style='height: 5px;'></div>")

    # 1. Data Ingestion Phase

    s1_q3_df = load_portfolio_data("SET-1 query 3.csv")
    s1_q4_df = load_portfolio_data("SET-1 query 4.csv")
    s3_m6_q3_df = load_portfolio_data("SET-3 Mart-6 3.csv")
    s1_q5_df = load_portfolio_data("SET-1 query 5.csv")
    s1_q6_df = load_portfolio_data("SET-1 query 6.csv")
    s1_q7_df = load_portfolio_data("SET-1 query 7.csv")
    s1_q8_df = load_portfolio_data("SET-1 query 8.csv")
    m6_1_df = load_portfolio_data("SET-3 Mart-6 1.csv")
    m6_2_df = load_portfolio_data("SET-3 Mart-6 2.csv")
    m6_5_df = load_portfolio_data("SET-3 Mart-6 5.csv")
    

    
    # 2. Scalar Metric Extraction
    
    total_revenue_k = float(s1_q4_df['total_revenue'].iloc[0])/1000.0
    total_orders_k = int(s1_q4_df['total_orders'].iloc[0])/1000.0
    total_items_sold_k = int(s1_q3_df['total_items_sold'].iloc[0])/1000.0
    AOV = float(s1_q4_df['AOV'].iloc[0])
    product_hhi = int(s3_m6_q3_df['hhi_product'].iloc[0])
    
    
    
    
    # 3. Horizontal Grid Layout Allocation (5-Column Matrix Row)
    c1, c2, c3, c4, c5 = st.columns(5)
    
    c1.metric(label="Total Gross Revenue", value=f'${total_revenue_k:,.2f} K')
    c2.metric(label="Total Orders Placed", value=f'{total_orders_k:.1f} K')
    c3.metric(label="Total Items Sold", value=f'{total_items_sold_k:.2f} K')
    c4.metric(label="Average Order Value (AOV)", value=f'${AOV:,.2f}')
    c5.metric(label="Product HHI", value=f'{product_hhi}', delta="SAFE DIVERSIFIED", delta_color="normal")
    
    st.markdown("---")



    #4. MARKET SHARE DYNAMICS ROW
#     st.write("### Market Share Distribution & Asset Output Velocity")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>Market Share Distribution & Asset Output Velocity</h3>", 
        unsafe_allow_html=True
    )

    with st.container(border=True):

        chart_col_1, chart_col_2 = st.columns(2)

        with chart_col_1:
            st.write("#### Revenue Contribution by Product Category")
            fig_pie = px.pie(
                s1_q5_df,
                values='total_sales_kpi',
                names='category',
                hole=0.45,
                color_discrete_sequence=px.colors.qualitative.Pastel
            )
            fig_pie.update_layout(margin=dict(l=20, r=20, t=20, b=20))
            st.plotly_chart(fig_pie, use_container_width=True)
            

           
        with chart_col_2:
            st.write("#### Top Selling Menu Items Output Velocity")
            
            df_sorted = s1_q6_df.sort_values(by='total_sales_kpi', ascending=True)
            
            fig_bar = px.bar(
                df_sorted, 
                x='total_sales_kpi', 
                y='item_name',
                orientation='h', 
                color='total_sales_kpi', 
                color_continuous_scale='Blues'
            )
            
            # Configure advanced hover cards with premium currency styling
            fig_bar.update_traces(
                hovertemplate="<b>Item Focus:</b> %{y}<br><b>Gross Sales:</b> $%{x:,.2f}<extra></extra>"
            )
            
            # Zoom the view to focus exclusively on the competition zone
            fig_bar.update_xaxes(range=[95000, 110000])
            
            fig_bar.update_layout(margin=dict(l=20, r=20, t=20, b=20), coloraxis_showscale=False)
            st.plotly_chart(fig_bar, use_container_width=True)


    
        
    st.markdown("---")





    #5. GEOSPATIAL ANALYSIS LAYER (SET-1 Queries 7 & 8)

#     st.write("### Geographic Capture & Fulfillment Map Matrix")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>Geographic Capture & Fulfillment Map Matrix</h3>", 
        unsafe_allow_html=True
    )
    
    # Injects an exact 5-pixel invisible gap on your canvas row
    st.html("<div style='height: 5px;'></div>")
    
    map_perspective = st.radio(
        "Select Geospatial Perspective Layer:", 
        ["Regional Sales Distribution (RSD)", "Fulfillment Mapping (GFM)"], 
        horizontal=True
    )
    
    if map_perspective == "Regional Sales Distribution (RSD)":
        st.map(
            data=s1_q7_df,
            latitude='latitude',
            longitude='longitude',
            size='total_sales',
            color='#1f77b4',
            use_container_width=True)
    else:
        st.map(
            data=s1_q8_df,
            latitude='latitude',
            longitude='longitude',
            size='total_orders',
            color='#ff7f0e',
            use_container_width=True)
    
    
    
    st.markdown("---")
    
    
    


    #6. MACRO MOMENTUM TIMELINE GRAPHS (SET-3 Mart-6 1 & 2)

#     st.write("### Operational Acceleration & Order Throughput Velocity")
    
    # Centered alignment wrapper using standard HTML inline styles
    st.markdown(
        "<h3 style='text-align: center;'>Operational Acceleration & Order Throughput Velocity</h3>", 
        unsafe_allow_html=True
    )
    
    # Injects an exact 5-pixel invisible gap on your canvas row
    st.html("<div style='height: 5px;'></div>")
    
    # 1. Generate local distinct date sorting options directly from your dataset
    available_dates = sorted(m6_1_df['order_date'].unique())
    
    # 2. Render an interactive localized slider/picker component above the graph column split
    selected_range = st.select_slider(
        "Isolate Specific Timeline Window (Applies to Trend Graphs Only):",
        options=available_dates,
        value=(available_dates[0], available_dates[-1])
    )
    
    # 3. Apply the filtering constraints to both timelines using vector slices
    start_date, end_date = selected_range
    filtered_m6_1 = m6_1_df[
        (m6_1_df['order_date'] >= start_date)
        & (m6_1_df['order_date'] <= end_date)]
    
    filtered_m6_2 = m6_2_df[
        (m6_2_df['order_date'] >= start_date)
        & (m6_2_df['order_date'] <= end_date)]
    
    # 4. Generate the horizontal layout grid containing the isolated graphs
    timeline_col_1, timeline_col_2 = st.columns(2)
    
    with timeline_col_1:
        st.write("#### Revenue Growth Path Timeline")
        
        fig_revenue = px.line(
            filtered_m6_1,
            x='order_date',
            y='revenue',
            labels={
                'revenue': 'Daily Sales ($)',
                'order_date': 'Timeline'},
            color_discrete_sequence=['#2ca02c'])
        
        st.plotly_chart(fig_revenue, use_container_width=True)
        
    with timeline_col_2:
        st.write("#### System Order Processing Speed")
        
        fig_throughput = px.line(
            filtered_m6_2,
            x='order_date',
            y='order_velocity',
            labels={
                'order_velocity': 'Orders/Day',
                'order_date': 'Timeline'},
            color_discrete_sequence=['#9467bd'])
        
        st.plotly_chart(fig_throughput, use_container_width=True)
    
    
    
    st.markdown("---")




    
    
    #7. ENTERPRISE HEALTH DATA FRAME (SET-3 Mart-6 5)

#     st.write("### Business Momentum Score (Composite Performance Evaluation)")
    
    st.markdown(
        "<h3 style='text-align: center;'>Business Momentum Score (Composite Performance Evaluation)</h3>", 
        unsafe_allow_html=True
    )
    
    # Injects an exact 5-pixel invisible gap on your canvas row
    st.html("<div style='height: 5px;'></div>")

    with st.container(border=True):
    
        # 1. Establish side-by-side layout columns for the slicer dropdown components
        slicer_col_1, slicer_col_2 = st.columns(2)
        
        with slicer_col_1:
            # Pull distinct values for fiscal month
            distinct_months = sorted(m6_5_df['fiscal_month'].unique())
            selected_months = st.multiselect(
                "Filter by Fiscal Month:", 
                options=distinct_months, 
                default=distinct_months
            )
            
        with slicer_col_2:
            # Pull distinct values for enterprise health grade
            distinct_grades = sorted(m6_5_df['overall_enterprise_health_grade'].unique())
            selected_grades = st.multiselect(
                "Filter by Enterprise Grade Profile:", 
                options=distinct_grades, 
                default=distinct_grades
            )
            
        # 2. Apply both slicer selections to memory filter the dataframe simultaneously
        filtered_m6_5 = m6_5_df[
            (m6_5_df['fiscal_month'].isin(selected_months)) & 
            (m6_5_df['overall_enterprise_health_grade'].isin(selected_grades))
        ]
        
        # 3. Render the dynamic filtered results grid
        st.dataframe(
            
            filtered_m6_5,
            
            column_config={
                "fiscal_month": st.column_config.TextColumn("Fiscal Month"),
                
                "gross_sales": st.column_config.NumberColumn(
                    "Gross Monthly Revenue ($)",
                    format="$%,.2f"),
                
                "ticket_velocity": st.column_config.NumberColumn("Total Ticket Volume"),
                
                "corporate_momentum_index_score": st.column_config.NumberColumn("Momentum Score"),
                
                "overall_enterprise_health_grade": st.column_config.TextColumn("Enterprise Grade Profile")
            },
            
            use_container_width=True,
            hide_index=True
        )


    









