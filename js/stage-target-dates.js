// ============================================================================
// Stage Target Dates Management Module
// ============================================================================
// This module handles setting, displaying, and managing target dates for 
// shipment stages with visual indicators for status
// ============================================================================

export class StageTargetDates {
  constructor(supabase, shipmentId) {
    this.supabase = supabase;
    this.shipmentId = shipmentId;
    this.targetDates = [];
  }

  // Load all target dates for the shipment
  async loadTargetDates() {
    try {
      console.log('🔍 Loading target dates for shipment:', this.shipmentId);
      
      const { data, error } = await this.supabase
        .rpc('get_shipment_stage_targets', {
          p_shipment_id: this.shipmentId
        });

      if (error) {
        // Check if it's because the function doesn't exist
        if (error.message && (error.message.includes('does not exist') || error.code === '42883')) {
          console.warn('⚠️ Target dates feature not set up yet. Run add_stage_target_dates.sql to enable this feature.');
          this.targetDates = [];
          return [];
        }
        console.error('❌ Error loading target dates:', error);
        this.targetDates = [];
        return [];
      }
      
      this.targetDates = data || [];
      console.log('✅ Loaded target dates:', this.targetDates.length, 'targets found');
      if (this.targetDates.length > 0) {
        console.log('Target dates data:', this.targetDates);
      }
      
      return this.targetDates;
    } catch (error) {
      console.error('❌ Fatal error loading target dates:', error);
      console.error('Error details:', error.message, error.code);
      this.targetDates = [];
      return [];
    }
  }

  // Get target date for a specific stage
  getTargetDateForStage(stageName) {
    // Skip documents stage as it's not in the stage enum
    if (stageName === 'documents') return null;
    return this.targetDates.find(td => td.stage_name === stageName);
  }

  // Set or update target date for a stage
  async setTargetDate(stageName, targetDate, notes = null) {
    try {
      console.log('💾 Setting target date:', { stageName, targetDate, notes, shipmentId: this.shipmentId });
      
      const { data: { user } } = await this.supabase.auth.getUser();
      console.log('👤 User ID:', user?.id);
      
      const { data, error } = await this.supabase
        .rpc('set_stage_target_date', {
          p_shipment_id: this.shipmentId,
          p_stage_name: stageName,
          p_target_date: targetDate,
          p_notes: notes,
          p_user_id: user?.id
        });

      if (error) {
        console.error('❌ Error saving target date:', error);
        throw error;
      }
      
      console.log('✅ Target date saved successfully, ID:', data);
      
      // Reload target dates
      await this.loadTargetDates();
      
      return { success: true, id: data };
    } catch (error) {
      console.error('❌ Fatal error setting target date:', error);
      console.error('Error details:', error.message, error.code);
      return { success: false, error: error.message };
    }
  }

  // Delete target date
  async deleteTargetDate(targetId) {
    try {
      const { data, error } = await this.supabase
        .rpc('delete_stage_target_date', {
          p_stage_target_id: targetId
        });

      if (error) throw error;
      
      // Reload target dates
      await this.loadTargetDates();
      
      return { success: true };
    } catch (error) {
      console.error('Error deleting target date:', error);
      return { success: false, error: error.message };
    }
  }

  // Get status badge HTML for a stage
  getStatusBadge(targetDate) {
    if (!targetDate) return '';

    const { status, days_remaining } = targetDate;
    
    let badgeClass = '';
    let badgeText = '';
    let icon = '';

    switch (status) {
      case 'overdue':
        badgeClass = 'status-overdue';
        badgeText = `Overdue by ${Math.abs(days_remaining)} day(s)`;
        icon = '<i class="fas fa-exclamation-circle"></i>';
        break;
      case 'warning':
        badgeClass = 'status-warning';
        badgeText = `${days_remaining} day(s) remaining`;
        icon = '<i class="fas fa-clock"></i>';
        break;
      case 'on_track':
        badgeClass = 'status-on-track';
        badgeText = `${days_remaining} day(s) remaining`;
        icon = '<i class="fas fa-check-circle"></i>';
        break;
    }

    return `
      <div class="target-date-badge ${badgeClass}">
        ${icon}
        <span>${badgeText}</span>
      </div>
    `;
  }

  // Open modal to set/edit target date for a stage
  openTargetDateModal(stageName, stageDisplayName) {
    const existingTarget = this.getTargetDateForStage(stageName);
    
    const modal = document.createElement('div');
    modal.className = 'modal show';
    modal.id = 'target-date-modal';
    
    const today = new Date().toISOString().split('T')[0];
    
    modal.innerHTML = `
      <div class="modal-content" style="max-width: 500px;">
        <span class="close-button" onclick="document.getElementById('target-date-modal').remove()">&times;</span>
        <h2><i class="fas fa-calendar-alt"></i> Set Target Date</h2>
        <p style="color: #6b7280; margin-bottom: 20px;">
          Set a target completion date for <strong>${stageDisplayName}</strong>
        </p>
        
        <form id="target-date-form">
          <div class="form-field">
            <label for="target-date-input">
              Target Date: <span style="color: #ef4444;">*</span>
            </label>
            <input 
              type="date" 
              id="target-date-input" 
              name="target_date" 
              min="${today}"
              value="${existingTarget ? existingTarget.target_date : ''}"
              required
            />
            <small class="field-hint">
              Alerts will be sent 3 days before and on the day if overdue
            </small>
          </div>
          
          <div class="form-field">
            <label for="target-date-notes">Notes (Optional):</label>
            <textarea 
              id="target-date-notes" 
              name="notes" 
              rows="3"
              placeholder="Add any notes about this target date..."
            >${existingTarget ? existingTarget.notes || '' : ''}</textarea>
          </div>
          
          ${existingTarget ? `
          <div class="form-field" style="background: #f3f4f6; padding: 10px; border-radius: 6px; margin-top: 15px;">
            <p style="margin: 0; font-size: 13px; color: #6b7280;">
              <i class="fas fa-info-circle"></i> <strong>Alert Status:</strong><br/>
              3-Day Alert: ${existingTarget.three_day_alert_sent ? '✅ Sent' : '⏳ Pending'}<br/>
              Overdue Alert: ${existingTarget.overdue_alert_sent ? '✅ Sent' : '⏳ Pending'}
            </p>
          </div>
          ` : ''}
          
          <div class="button-container" style="margin-top: 20px;">
            <button type="submit" class="button button-primary">
              <i class="fas fa-save"></i> Save Target Date
            </button>
            ${existingTarget ? `
            <button type="button" class="button button-secondary" onclick="handleDeleteTargetDate('${existingTarget.id}')">
              <i class="fas fa-trash"></i> Delete
            </button>
            ` : ''}
            <button type="button" class="button button-secondary" onclick="document.getElementById('target-date-modal').remove()">
              Cancel
            </button>
          </div>
        </form>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    // Handle form submission
    const form = document.getElementById('target-date-form');
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      
      const formData = new FormData(form);
      const targetDate = formData.get('target_date');
      const notes = formData.get('notes');
      
      // Show loading state
      const submitBtn = form.querySelector('button[type="submit"]');
      const originalText = submitBtn.innerHTML;
      submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
      submitBtn.disabled = true;
      
      const result = await this.setTargetDate(stageName, targetDate, notes || null);
      
      if (result.success) {
        showToast('Target date saved successfully!', true);
        modal.remove();
        
        // Trigger a refresh of the UI
        if (window.refreshStageTargetDates) {
          window.refreshStageTargetDates();
        }
      } else {
        showToast(`Error: ${result.error}`, false);
        submitBtn.innerHTML = originalText;
        submitBtn.disabled = false;
      }
    });
  }

  // Render target date section for timeline
  renderTimelineTargetDate(stageName) {
    // Skip documents stage as it's not in the stage enum
    if (stageName === 'documents') return '';
    
    const targetDate = this.getTargetDateForStage(stageName);
    
    if (!targetDate) return '';
    
    const dateStr = new Date(targetDate.target_date).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
    
    let statusClass = '';
    let statusIcon = '';
    let statusText = '';
    
    switch (targetDate.status) {
      case 'overdue':
        statusClass = 'target-overdue';
        statusIcon = '<i class="fas fa-exclamation-triangle"></i>';
        statusText = `Target: ${dateStr} (${Math.abs(targetDate.days_remaining)}d overdue)`;
        break;
      case 'warning':
        statusClass = 'target-warning';
        statusIcon = '<i class="fas fa-clock"></i>';
        statusText = `Target: ${dateStr} (${targetDate.days_remaining}d left)`;
        break;
      case 'on_track':
        statusClass = 'target-on-track';
        statusIcon = '<i class="fas fa-calendar-check"></i>';
        statusText = `Target: ${dateStr}`;
        break;
    }
    
    return `
      <div class="timeline-target-date ${statusClass}">
        ${statusIcon}
        <span>${statusText}</span>
      </div>
    `;
  }

  // Render target dates summary panel
  renderTargetDatesSummary() {
    console.log('📊 Rendering summary for', this.targetDates.length, 'target dates');
    
    if (this.targetDates.length === 0) {
      console.log('ℹ️ No target dates to display');
      return `
        <div class="target-dates-summary empty">
          <p><i class="fas fa-calendar-times"></i> No target dates set</p>
        </div>
      `;
    }

    const overdueCount = this.targetDates.filter(td => td.status === 'overdue').length;
    const warningCount = this.targetDates.filter(td => td.status === 'warning').length;
    const onTrackCount = this.targetDates.filter(td => td.status === 'on_track').length;
    
    console.log('📈 Summary stats - Overdue:', overdueCount, 'Warning:', warningCount, 'On Track:', onTrackCount);

    return `
      <div class="target-dates-summary">
        <h4><i class="fas fa-calendar-alt"></i> Target Dates Overview</h4>
        <div class="target-stats">
          ${overdueCount > 0 ? `
          <div class="target-stat overdue">
            <i class="fas fa-exclamation-circle"></i>
            <span class="stat-value">${overdueCount}</span>
            <span class="stat-label">Overdue</span>
          </div>
          ` : ''}
          ${warningCount > 0 ? `
          <div class="target-stat warning">
            <i class="fas fa-clock"></i>
            <span class="stat-value">${warningCount}</span>
            <span class="stat-label">Upcoming</span>
          </div>
          ` : ''}
          <div class="target-stat on-track">
            <i class="fas fa-check-circle"></i>
            <span class="stat-value">${onTrackCount}</span>
            <span class="stat-label">On Track</span>
          </div>
        </div>
      </div>
    `;
  }
}

// Global function for delete button
window.handleDeleteTargetDate = async function(targetId) {
  if (!confirm('Are you sure you want to delete this target date? Alert history will be lost.')) {
    return;
  }
  
  if (window.stageTargetDatesManager) {
    const result = await window.stageTargetDatesManager.deleteTargetDate(targetId);
    
    if (result.success) {
      showToast('Target date deleted successfully!', true);
      document.getElementById('target-date-modal').remove();
      
      if (window.refreshStageTargetDates) {
        window.refreshStageTargetDates();
      }
    } else {
      showToast(`Error: ${result.error}`, false);
    }
  }
};

// Helper function (assumes showToast is available globally)
function showToast(message, isSuccess = true) {
  const toast = document.getElementById('toast-message');
  if (!toast) return;
  
  toast.className = 'toast-notification';
  if (isSuccess) {
    toast.classList.add('success');
    toast.innerHTML = `<i class="fas fa-check-circle icon"></i> ${message}`;
  } else {
    toast.classList.add('error');
    toast.innerHTML = `<i class="fas fa-exclamation-circle icon"></i> ${message}`;
  }
  
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}
