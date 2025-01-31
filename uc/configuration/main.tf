terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.15.0"
    }
  }
}

# Provider configuration for Azure Databricks.
provider "databricks" {
  # Replace the fake resource ID below with your actual Azure Databricks workspace resource ID.
  azure_workspace_resource_id = var.databricks_workspace_resource_id
}

##############################
# 1. Create a Unity Catalog  #
##############################

resource "databricks_catalog" "uc_catalog" {
  name    = "fake_unity_catalog"
  comment = "Unity Catalog created via Terraform with fake values"
}

##############################
# 2. Create a Schema in the Catalog #
##############################

resource "databricks_schema" "uc_schema" {
  name         = "fake_schema"
  catalog_name = databricks_catalog.uc_catalog.name
  comment      = "Schema for storing tables in our fake catalog"
}

##############################
# 3. Create an Example Table #
##############################

# resource "databricks_table" "uc_table" {
#   name         = "fake_table"
#   catalog_name = databricks_catalog.uc_catalog.name
#   schema_name  = databricks_schema.uc_schema.name
#   comment      = "Example table created by Terraform with fake values"

#   # For demonstration, we’re not defining columns and other table properties.
#   # In a real setup, add additional configuration for your table.
# }

###########################################
# 4. Assign Permissions to the Catalog, Schema
###########################################

# Catalog permissions: allow specified groups to manage or use the catalog.

resource "databricks_grants" "catalog_grants" {
  catalog = databricks_catalog.uc_catalog.name

  grant {
    principal  = "data_engineers"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }

  grant {
    principal  = "data_analysts"
    privileges = ["USE_SCHEMA", "CREATE_SCHEMA", "CREATE_TABLE", "MODIFY"]

  }
}

resource "databricks_grants" "schema_grants" {
  schema = "${databricks_catalog.uc_catalog.name}.${databricks_schema.uc_schema.name}"


  grant {
    principal  = "data_engineers"
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY", "SELECT"]
  }

  grant {
    principal  = "data_analysts"
    privileges = ["USE_SCHEMA", "CREATE_TABLE", "MODIFY"]

  }
}
