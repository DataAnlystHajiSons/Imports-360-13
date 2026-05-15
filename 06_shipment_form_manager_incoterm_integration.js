/**
 * ========================================================================
 * ShipmentFormManager - Inco-term Integration Updates
 * ========================================================================
 * Add these methods and updates to your ShipmentFormManager.js
 * ========================================================================
 */

// Add this constant at the top of the file
const INCOTERM_OPTIONS = {
  air: [
    { value: 'FCA', label: 'FCA (Free Carrier)' },
    { value: 'EXW', label: 'EXW (Ex Works)' },
    { value: 'CPT', label: 'CPT (Carriage Paid To)' }
  ],
  sea: [
    { value: 'EXW', label: 'EXW (Ex Works)' },
    { value: 'FOB', label: 'FOB (Free On Board)' },
    { value: 'CFR', label: 'CFR (Cost and Freight)' }
  ],
  land: [
    { value: 'FCA', label: 'FCA (Free Carrier)' },
    { value: 'EXW', label: 'EXW (Ex Works)' },
    { value: 'CPT', label: 'CPT (Carriage Paid To)' }
  ],
  rail: [
    { value: 'FCA', label: 'FCA (Free Carrier)' },
    { value: 'EXW', label: 'EXW (Ex Works)' },
    { value: 'CPT', label: 'CPT (Carriage Paid To)' }
  ],
  multimodal: [
    { value: 'FCA', label: 'FCA (Free Carrier)' },
    { value: 'EXW', label: 'EXW (Ex Works)' },
    { value: 'CPT', label: 'CPT (Carriage Paid To)' },
    { value: 'DDP', label: 'DDP (Delivered Duty Paid)' }
  ]
};

// ========================================================================
// ADD THESE METHODS TO ShipmentFormManager CLASS
// ========================================================================

/**
 * Initialize inco-term dynamic behavior
 * Call this in attachEventListeners() method
 */
setupIncotermLogic() {
  const modeSelect = this.form.querySelector('[name="mode_of_transport"]');
  const incotermSelect = this.form.querySelector('[name="inco_term"]');
  
  if (!modeSelect || !incotermSelect) {
    console.warn('Mode of transport or inco-term select not found');
    return;
  }
  
  // Listen for mode of transport changes
  modeSelect.addEventListener('change', () => {
    this.updateIncotermOptions();
    // Reset inco-term when mode changes
    incotermSelect.value = '';
    this.toggleFreightChargesField();
  });
  
  // Listen for inco-term changes
  incotermSelect.addEventListener('change', () => {
    this.toggleFreightChargesField();
  });
  
  // Initial update
  this.updateIncotermOptions();
  this.toggleFreightChargesField();
}

/**
 * Update inco-term dropdown options based on selected mode of transport
 */
updateIncotermOptions() {
  const modeSelect = this.form.querySelector('[name="mode_of_transport"]');
  const incotermSelect = this.form.querySelector('[name="inco_term"]');
  const incotermHint = document.getElementById('incoterm-hint');
  
  if (!modeSelect || !incotermSelect) return;
  
  const modeOfTransport = modeSelect.value;
  
  // Clear existing options
  incotermSelect.innerHTML = '';
  
  if (!modeOfTransport) {
    incotermSelect.innerHTML = '<option value="">Select mode of transport first</option>';
    incotermSelect.disabled = true;
    if (incotermHint) {
      incotermHint.textContent = 'Select mode of transport to see available inco-terms';
    }
    return;
  }
  
  // Get options for selected mode
  const options = INCOTERM_OPTIONS[modeOfTransport] || [];
  
  if (options.length === 0) {
    incotermSelect.innerHTML = '<option value="">No inco-terms available</option>';
    incotermSelect.disabled = true;
    return;
  }
  
  // Add placeholder
  incotermSelect.innerHTML = '<option value="">Select inco-term</option>';
  
  // Add options
  options.forEach(opt => {
    const option = document.createElement('option');
    option.value = opt.value;
    option.textContent = opt.label;
    incotermSelect.appendChild(option);
  });
  
  // Enable the select
  incotermSelect.disabled = false;
  
  // Update hint
  if (incotermHint) {
    const modeLabel = {
      'air': 'Air Freight',
      'sea': 'Sea Freight',
      'land': 'Land Transport',
      'rail': 'Rail Transport',
      'multimodal': 'Multimodal'
    }[modeOfTransport] || 'selected mode';
    
    incotermHint.textContent = `Available inco-terms for ${modeLabel}`;
  }
}

/**
 * Show/hide freight charges field based on inco-term selection
 */
toggleFreightChargesField() {
  const incotermSelect = this.form.querySelector('[name="inco_term"]');
  const freightChargesField = document.getElementById('freight-charges-field');
  const freightChargesInput = this.form.querySelector('[name="freight_charges"]');
  
  if (!incotermSelect || !freightChargesField || !freightChargesInput) return;
  
  const incotermValue = incotermSelect.value;
  
  if (incotermValue === 'FOB') {
    freightChargesField.style.display = 'block';
    freightChargesInput.required = true;
  } else {
    freightChargesField.style.display = 'none';
    freightChargesInput.required = false;
    freightChargesInput.value = ''; // Clear value when hidden
  }
}

/**
 * UPDATE validateCurrentStep() method to include inco-term validation
 */
validateCurrentStep() {
  // Clear previous messages
  this.showMessage('', 'info');
  
  if (this.currentStep === 1) {
    // Validate products
    if (this.productRows.length === 0) {
      this.showMessage('Please add at least one product', 'error');
      return false;
    }
    
    const allValid = this.productRows.every(row => row.isValid());
    if (!allValid) {
      this.showMessage('Please fill in all product fields correctly', 'error');
      return false;
    }
    
    return true;
  }
  
  if (this.currentStep === 2) {
    // Validate shipment details
    const type = this.form.querySelector('[name="type"]').value;
    const modeOfTransport = this.form.querySelector('[name="mode_of_transport"]').value;
    const incoTerm = this.form.querySelector('[name="inco_term"]').value;
    const paymentTermId = this.form.querySelector('[name="payment_term_id"]').value;
    
    if (!type) {
      this.showMessage('Please select a shipment type', 'error');
      return false;
    }
    
    if (!modeOfTransport) {
      this.showMessage('Please select a mode of transport', 'error');
      return false;
    }
    
    if (!incoTerm) {
      this.showMessage('Please select an inco-term', 'error');
      return false;
    }
    
    // Validate freight charges if FOB
    if (incoTerm === 'FOB') {
      const freightCharges = this.form.querySelector('[name="freight_charges"]').value;
      if (!freightCharges || parseFloat(freightCharges) <= 0) {
        this.showMessage('Please enter valid FOB charges (required for FOB)', 'error');
        return false;
      }
    }
    
    if (!paymentTermId) {
      this.showMessage('Please select a payment term', 'error');
      return false;
    }
    
    // Populate review before moving to step 3
    this.populateReview();
    return true;
  }
  
  return true;
}

/**
 * UPDATE populateReview() method to include inco-term and freight charges
 */
populateReview() {
  const reviewContainer = this.form.querySelector('.review-container');
  if (!reviewContainer) return;
  
  // Get form data
  const formData = this.getFormData();
  
  // Clear existing content
  reviewContainer.innerHTML = '';
  
  // Products section
  const productsCard = document.createElement('div');
  productsCard.className = 'review-card';
  productsCard.innerHTML = `
    <div class="review-card-header">
      <h4><i class="fas fa-box"></i> Products</h4>
      <button type="button" class="edit-section-btn" data-goto-step="1">
        <i class="fas fa-edit"></i> Edit
      </button>
    </div>
    <div class="review-card-body">
      <table class="review-table">
        <thead>
          <tr>
            <th>Product</th>
            <th>Variety</th>
            <th>Quantity</th>
            <th>Unit</th>
          </tr>
        </thead>
        <tbody>
          ${formData.products.map(p => `
            <tr>
              <td>${p.productName}</td>
              <td>${p.varietyName}</td>
              <td>${p.quantity}</td>
              <td>${p.unit}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>
  `;
  reviewContainer.appendChild(productsCard);
  
  // Shipment details section (UPDATED with inco-term and freight charges)
  const detailsCard = document.createElement('div');
  detailsCard.className = 'review-card';
  
  let freightChargesRow = '';
  if (formData.inco_term === 'FOB' && formData.freight_charges) {
    freightChargesRow = `
      <tr>
        <td class="review-label">FOB Charges:</td>
        <td class="review-value">$${parseFloat(formData.freight_charges).toFixed(2)} USD</td>
      </tr>
    `;
  }
  
  detailsCard.innerHTML = `
    <div class="review-card-header">
      <h4><i class="fas fa-info-circle"></i> Shipment Details</h4>
      <button type="button" class="edit-section-btn" data-goto-step="2">
        <i class="fas fa-edit"></i> Edit
      </button>
    </div>
    <div class="review-card-body">
      <table class="review-table">
        <tbody>
          <tr>
            <td class="review-label">Shipment Type:</td>
            <td class="review-value">${formData.type === 'LC' ? 'LC (Letter of Credit)' : 'DP (Documents against Payment)'}</td>
          </tr>
          <tr>
            <td class="review-label">Mode of Transport:</td>
            <td class="review-value">${this.getModeOfTransportLabel(formData.mode_of_transport)}</td>
          </tr>
          <tr>
            <td class="review-label">Inco-term:</td>
            <td class="review-value">${this.getIncotermLabel(formData.inco_term)}</td>
          </tr>
          ${freightChargesRow}
          <tr>
            <td class="review-label">Payment Term:</td>
            <td class="review-value">${formData.paymentTermName}</td>
          </tr>
        </tbody>
      </table>
    </div>
  `;
  reviewContainer.appendChild(detailsCard);
  
  // Re-attach edit button listeners
  reviewContainer.querySelectorAll('.edit-section-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const targetStep = parseInt(e.currentTarget.dataset.gotoStep);
      this.goToStep(targetStep);
    });
  });
}

/**
 * Helper method to get mode of transport label
 */
getModeOfTransportLabel(mode) {
  const labels = {
    'sea': 'Sea Freight',
    'air': 'Air Freight',
    'land': 'Land Transport',
    'rail': 'Rail Transport',
    'multimodal': 'Multimodal Transport'
  };
  return labels[mode] || mode;
}

/**
 * Helper method to get inco-term label
 */
getIncotermLabel(incoterm) {
  const labels = {
    'EXW': 'EXW (Ex Works)',
    'FOB': 'FOB (Free On Board)',
    'CFR': 'CFR (Cost and Freight)',
    'FCA': 'FCA (Free Carrier)',
    'CPT': 'CPT (Carriage Paid To)',
    'DDP': 'DDP (Delivered Duty Paid)'
  };
  return labels[incoterm] || incoterm;
}

/**
 * UPDATE getFormData() method to include inco-term and freight charges
 */
getFormData() {
  const products = this.productRows.map(row => row.getData());
  const type = this.form.querySelector('[name="type"]').value;
  const modeOfTransport = this.form.querySelector('[name="mode_of_transport"]').value;
  const incoTerm = this.form.querySelector('[name="inco_term"]').value;
  const freightCharges = this.form.querySelector('[name="freight_charges"]')?.value || null;
  const paymentTermId = this.form.querySelector('[name="payment_term_id"]').value;
  
  // Get payment term name
  const paymentTermSelect = this.form.querySelector('[name="payment_term_id"]');
  const paymentTermName = paymentTermSelect.options[paymentTermSelect.selectedIndex]?.text || '';
  
  return {
    products,
    type,
    mode_of_transport: modeOfTransport,
    inco_term: incoTerm,
    freight_charges: freightCharges,
    payment_term_id: paymentTermId,
    paymentTermName
  };
}

// ========================================================================
// UPDATE attachEventListeners() METHOD
// Add this call in your attachEventListeners() method:
// ========================================================================
/*
attachEventListeners() {
  // ... existing code ...
  
  // Setup inco-term dynamic logic
  this.setupIncotermLogic();
  
  // ... rest of existing code ...
}
*/
