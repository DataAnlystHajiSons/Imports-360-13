# Fix Summary: Original Docs Stage Error

## Issue
When opening the **Original Docs** stage, an error occurred:
`Could not embed because more than one relationship was found for 'original_docs' and 'app_user'`

## Cause
The `original_docs` table has three foreign keys pointing to the `app_user` table:
1. `uploaded_by` -> `app_user(id)`
2. `created_by` -> `app_user(id)`
3. `updated_by` -> `app_user(id)`

When the code tried to fetch the `uploaded_by` user details using a generic embedding (e.g., `uploaded_by:app_user(...)`), PostgREST could not determine which foreign key relationship to use.

## Solution
1.  **Updated `renderStageView` in `js/shipment-tracker.js`**:
    - Added support for a `constraint` property in the stage configuration fields.
    - If `constraint` is provided, the query builder now explicitly specifies the foreign key constraint using the `!constraintName` syntax (e.g., `uploaded_by:app_user!original_docs_uploaded_by_fkey(...)`).

2.  **Updated `original_docs` Configuration**:
    - Modified the `uploaded_by` field configuration to include `constraint: "original_docs_uploaded_by_fkey"`.

## Changes Applied
- Modified `js/shipment-tracker.js`.

The "Original Docs" stage should now load correctly without errors.
