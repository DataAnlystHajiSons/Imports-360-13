# Role-Based Access Control Implementation Guide

## Overview
This system implements role-based access control to restrict page access based on user roles. Currently supported roles:
- **admin**: Full access to all pages
- **imports_ops**: Access only to forecast.html

## Files Modified

### 1. Created: `js/auth-utils.js`
Central authentication and authorization utility that provides:
- User authentication checking
- Role-based page access control
- Sidebar menu filtering
- Redirection logic

### 2. Updated: `forecast.html`
- Added auth enforcement
- Sidebar filtering based on role

### 3. Updated: `js/admin-dashboard.js`
- Added auth enforcement
- Sidebar filtering based on role

## How to Implement on Other Pages

### For HTML Pages with Inline Scripts

Add these lines to the beginning of your `<script type="module">` section:

```javascript
<script type="module">
  import { enforcePageAccess, filterSidebarByRole } from './js/auth-utils.js';
  import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
  
  const supabase = createClient("YOUR_SUPABASE_URL", "YOUR_SUPABASE_KEY");
  let userRole = null; // Store user role
  
  // In your window.onload or initialization function:
  window.onload = async () => {
    const loader = document.getElementById("loader");
    loader.style.display = "block";
    
    // Enforce page access and get user role
    const authData = await enforcePageAccess();
    if (!authData) {
        return; // enforcePageAccess handles redirection
    }
    
    userRole = authData.role;
    
    // Filter sidebar based on user role
    filterSidebarByRole(userRole);
    
    // Rest of your initialization code...
    loader.style.display = "none";
  };
</script>
```

### For External JavaScript Files

Add these lines at the top of your JS file:

```javascript
import { enforcePageAccess, filterSidebarByRole } from './auth-utils.js';
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const supabase = createClient("YOUR_SUPABASE_URL", "YOUR_SUPABASE_KEY");
let userRole = null; // Store user role

// In your DOMContentLoaded or initialization:
document.addEventListener('DOMContentLoaded', async () => {
    // Enforce page access and get user role
    const authData = await enforcePageAccess();
    if (!authData) {
        return; // enforcePageAccess handles redirection
    }
    
    userRole = authData.role;
    
    // Filter sidebar based on user role
    filterSidebarByRole(userRole);
    
    // Rest of your initialization code...
});
```

## Adding New Roles or Pages

### To Add a New Role
Edit `js/auth-utils.js` and update the `PAGE_ACCESS` and `MENU_CONFIG` objects:

```javascript
const PAGE_ACCESS = {
  admin: [...], // All pages
  imports_ops: ['forecast.html'],
  your_new_role: ['page1.html', 'page2.html'] // Add your new role
};

const MENU_CONFIG = {
  admin: 'all',
  imports_ops: ['forecast.html'],
  your_new_role: ['page1.html', 'page2.html'] // Add menu items for new role
};
```

### To Add a New Page to a Role
Simply add the page filename to the role's array in both `PAGE_ACCESS` and `MENU_CONFIG`.

## How It Works

1. **Page Load**: When a page loads, `enforcePageAccess()` is called
2. **Auth Check**: System checks if user is authenticated via Supabase
3. **Role Fetch**: User's role is fetched from the `app_user` table
4. **Access Check**: System checks if user's role has access to current page
5. **Redirection**: If unauthorized, user is redirected to their default page
6. **Sidebar Filter**: Sidebar menu items are hidden/shown based on role

## Access Behavior

### Admin Role
- Can access all pages
- Sees all sidebar menu items
- No restrictions

### Imports_Ops Role
- Can only access: `forecast.html`
- Only sees "Forecasts" in sidebar menu
- Attempting to access other pages redirects to `forecast.html`

### Unauthenticated Users
- Redirected to `login.html`
- Must log in to access any protected page

## Testing

### Test as Admin
1. Login with admin credentials
2. Should see all menu items
3. Should access all pages without restriction

### Test as Imports_Ops
1. Login with imports_ops credentials
2. Should only see "Forecasts" in sidebar
3. Attempting to navigate to other pages should redirect to forecast.html

## Security Notes

- All page access is enforced on page load
- Direct URL access is blocked via `enforcePageAccess()`
- Sidebar filtering is cosmetic but backed by actual access control
- Role data comes from Supabase `app_user` table
- Authentication state is managed by Supabase Auth

## Adding Logout Button

### HTML Button
Add this button to your page header:

```html
<button onclick="handleLogout()" class="button-secondary" style="background: #dc3545; color: white; border-color: #dc3545;" title="Logout">
  <i class="fas fa-sign-out-alt"></i>
  <span>Logout</span>
</button>
```

### JavaScript Implementation (Option 1 - Using auth-utils)
Import and use the logout function from auth-utils:

```javascript
import { logout } from './js/auth-utils.js';

async function handleLogout() {
  if (confirm('Are you sure you want to logout?')) {
    try {
      await logout();
    } catch (error) {
      showToast(`Error logging out: ${error.message}`, false);
    }
  }
}
window.handleLogout = handleLogout;
```

### JavaScript Implementation (Option 2 - Direct)
Use Supabase directly:

```javascript
async function handleLogout() {
  if (confirm('Are you sure you want to logout?')) {
    const { error } = await supabase.auth.signOut();
    if (error) {
      console.error('Logout error:', error);
      showToast(`Error logging out: ${error.message}`, false);
    } else {
      window.location.href = 'login.html';
    }
  }
}
window.handleLogout = handleLogout;
```

## Future Enhancements

To add more granular permissions:
1. Extend `PAGE_ACCESS` with more detailed permission objects
2. Add action-level permissions (view, edit, delete)
3. Implement field-level access control
4. Add permission inheritance/hierarchies
