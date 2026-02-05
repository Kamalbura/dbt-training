# Shopify Analytics - dbt Project

A dbt project for transforming raw Shopify e-commerce data into analytics-ready tables.

## 📊 Data Sources

- **Shopify Orders**: Raw order data from Shopify/TikTok Shop integration

## 🏗️ Project Structure

```
models/
├── staging/shopify/          # Clean raw Shopify data
│   ├── stg_shopify__orders.sql
│   ├── stg_shopify__order_line_items.sql
│   └── stg_shopify__fulfillments.sql
└── marts/core/               # Business-ready analytics tables
    └── (future models)
```

## 🚀 Quick Start

```bash
# Install dependencies
dbt deps

# Test your connection
dbt debug

# Run all models
dbt run

# Run tests
dbt test

# Build everything (run + test)
dbt build
```

## 📚 Learning Resources

Check the `docs/` folder for explanation files:
- `dbt_project_explained.txt` - Understanding dbt_project.yml
- `folder_structure_explained.txt` - Why we organize files this way
- `sources_explained.txt` - How sources work
- `staging_models_explained.txt` - Building staging models

## 🔗 Resources
- [dbt Documentation](https://docs.getdbt.com/docs/introduction)
- [dbt Community](https://getdbt.com/community)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
