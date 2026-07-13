// js/user-management.js
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.4/+esm";

const supabaseUrl = "https://sfknzqkiqxivzcualcau.supabase.co";
const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma256cWtpcXhpdnpjdWFsY2F1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3OTU0ODksImV4cCI6MjA3MjM3MTQ4OX0.JKjOS9NRdbVH1UanfqmBeHmMSnlWlZtDr-5LdKw5YaA";
const supabase = createClient(supabaseUrl, supabaseKey);

let allUsers = [];

// Show/Hide Loader
function showLoader(show) {
    const loader = document.getElementById('loader');
    if (loader) {
        loader.style.opacity = show ? '1' : '0';
        setTimeout(() => {
            loader.style.display = show ? 'flex' : 'none';
        }, show ? 0 : 300);
    }
}

// Show Toast message
function showToast(message, isSuccess = true) {
    const toast = document.getElementById('toast-message');
    if (toast) {
        toast.textContent = message;
        toast.className = isSuccess ? 'show success' : 'show error';
        setTimeout(() => {
            toast.classList.remove('show');
        }, 3000);
    }
}

// Core Access Protection & Initialization
async function initializeUserManagement() {
    showLoader(true);
    try {
        // 1. Check active user session
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        if (sessionError || !session) {
            window.location.href = 'login.html';
            return;
        }

        const userId = session.user.id;

        // 2. Fetch active user's permissions/role
        const { data: appUser, error: appUserError } = await supabase
            .from('app_user')
            .select('*')
            .eq('id', userId)
            .single();

        if (appUserError || !appUser) {
            console.error('Error fetching user role:', appUserError);
            window.location.href = 'login.html';
            return;
        }

        // 3. SECURE ACCESS GUARD: strictly enforce super_admin role
        if (appUser.role !== 'super_admin') {
            console.warn('Unauthorized access attempt by:', appUser.email);
            window.location.href = 'admin-dashboard.html';
            return;
        }

        // 4. Populate header profile info
        document.getElementById('admin-user-name').textContent = appUser.full_name;
        document.getElementById('admin-user-role').textContent = 'Super Admin Account';

        // 5. Load user accounts list
        await loadUserAccounts();

    } catch (err) {
        console.error('Initialization error:', err);
        window.location.href = 'login.html';
    } finally {
        showLoader(false);
    }
}

// Fetch all users and calculate statistics
async function loadUserAccounts() {
    try {
        const { data: users, error: usersError } = await supabase
            .from('app_user')
            .select('*')
            .order('created_at', { ascending: false });

        if (usersError) throw usersError;

        allUsers = users || [];
        populateStatistics(allUsers);
        renderUsersList(allUsers);

    } catch (err) {
        console.error('Error loading users:', err);
        showToast('Error loading user accounts: ' + err.message, false);
    }
}

// Calculate Stats Cards counters
function populateStatistics(users) {
    const totalCount = users.length;
    const superAdminCount = users.filter(u => u.role === 'super_admin').length;
    const uniqueRolesCount = new Set(users.map(u => u.role)).size;

    document.getElementById('total-users-count').textContent = totalCount;
    document.getElementById('super-admins-count').textContent = superAdminCount;
    document.getElementById('active-roles-count').textContent = uniqueRolesCount;
}

// Render dynamic user list table
function renderUsersList(users) {
    const tbody = document.getElementById('users-table-body');
    tbody.innerHTML = '';

    if (users.length === 0) {
        tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: #64748b; padding: 32px;"><i class="fas fa-search" style="font-size: 1.5rem; margin-bottom: 8px; display: block;"></i> No matching user accounts found.</td></tr>`;
        return;
    }

    users.forEach(user => {
        const tr = document.createElement('tr');
        const formattedDate = new Date(user.created_at).toLocaleDateString('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });

        tr.innerHTML = `
            <td style="font-weight: 600; color: #0f172a;">${user.full_name}</td>
            <td style="font-family: monospace; color: #475569;">${user.email}</td>
            <td>
                <span class="role-badge role-${user.role}">${user.role.replace('_', ' ')}</span>
            </td>
            <td style="color: #64748b;">${formattedDate}</td>
            <td style="text-align: right;">
                <div class="actions-cell">
                    <button class="btn btn-secondary" onclick="openPasswordModal('${user.id}', '${user.email}')" title="Reset Password">
                        <i class="fas fa-key"></i> Pass
                    </button>
                    <button class="btn btn-secondary" onclick="openRoleModal('${user.id}', '${user.full_name}', '${user.role}')" title="Modify Role">
                        <i class="fas fa-user-tag"></i> Role
                    </button>
                    <button class="btn btn-danger" onclick="openDeleteModal('${user.id}', '${user.full_name}')" title="Delete User">
                        <i class="fas fa-trash-alt"></i>
                    </button>
                </div>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

// Modal Windows Managers

// 1. Password Reset Modal
window.openPasswordModal = function(id, email) {
    document.getElementById('reset-user-id').value = id;
    document.getElementById('reset-user-email').textContent = email;
    document.getElementById('new-password').value = '';
    document.getElementById('confirm-password').value = '';
    document.getElementById('password-modal').classList.add('show');
};

window.closePasswordModal = function() {
    document.getElementById('password-modal').classList.remove('show');
};

window.saveNewPassword = async function() {
    const id = document.getElementById('reset-user-id').value;
    const newPass = document.getElementById('new-password').value;
    const confirmPass = document.getElementById('confirm-password').value;

    if (newPass !== confirmPass) {
        showToast('Passwords do not match!', false);
        return;
    }

    showLoader(true);
    try {
        const { error } = await supabase.rpc('admin_update_user_password', {
            target_user_id: id,
            new_password: newPass
        });

        if (error) throw error;

        showToast('Password updated successfully!');
        closePasswordModal();
    } catch (err) {
        console.error('Password reset failed:', err);
        showToast('Failed to reset password: ' + err.message, false);
    } finally {
        showLoader(false);
    }
};

// 2. Modify Role Modal
window.openRoleModal = function(id, name, currentRole) {
    document.getElementById('role-user-id').value = id;
    document.getElementById('role-user-name').textContent = name;
    document.getElementById('new-role-select').value = currentRole;
    document.getElementById('role-modal').classList.add('show');
};

window.closeRoleModal = function() {
    document.getElementById('role-modal').classList.remove('show');
};

window.saveNewRole = async function() {
    const id = document.getElementById('role-user-id').value;
    const newRole = document.getElementById('new-role-select').value;

    showLoader(true);
    try {
        const { error } = await supabase.rpc('admin_update_user_role', {
            target_user_id: id,
            new_role: newRole
        });

        if (error) throw error;

        showToast('Role permissions updated successfully!');
        closeRoleModal();
        await loadUserAccounts(); // Refresh list to reflect role colors
    } catch (err) {
        console.error('Role update failed:', err);
        showToast('Failed to update role: ' + err.message, false);
    } finally {
        showLoader(false);
    }
};

// 3. Delete Confirmation Modal
window.openDeleteModal = function(id, name) {
    document.getElementById('delete-user-id').value = id;
    document.getElementById('delete-user-name').textContent = name;
    document.getElementById('delete-modal').classList.add('show');
};

window.closeDeleteModal = function() {
    document.getElementById('delete-modal').classList.remove('show');
};

window.executeDeleteUser = async function() {
    const id = document.getElementById('delete-user-id').value;

    showLoader(true);
    try {
        const { error } = await supabase.rpc('admin_delete_user', {
            target_user_id: id
        });

        if (error) throw error;

        showToast('User account successfully deleted!');
        closeDeleteModal();
        await loadUserAccounts(); // Refresh list
    } catch (err) {
        console.error('Deletion failed:', err);
        showToast('Failed to delete user: ' + err.message, false);
    } finally {
        showLoader(false);
    }
};

// Setup Search Filter Action
document.getElementById('user-search').addEventListener('input', (e) => {
    const term = e.target.value.toLowerCase().trim();
    if (!term) {
        renderUsersList(allUsers);
        return;
    }

    const filtered = allUsers.filter(user => 
        user.full_name.toLowerCase().includes(term) || 
        user.email.toLowerCase().includes(term) ||
        user.role.toLowerCase().includes(term)
    );
    renderUsersList(filtered);
});

// Run Page initialization
initializeUserManagement();
