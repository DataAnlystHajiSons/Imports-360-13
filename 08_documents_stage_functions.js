/**
 * ========================================================================
 * Documents Stage Management Functions
 * ========================================================================
 * Add these functions to shipment-tracker.js or create a separate
 * documents-manager.js file and import it
 * ========================================================================
 */

// Global state for documents
let currentShipmentId = null;
let allDocuments = [];
let currentCategory = 'all';

/**
 * Open the documents modal
 */
async function openDocumentsModal() {
  const modal = document.getElementById('documents-stage-modal');
  if (!modal) {
    console.error('Documents modal not found');
    return;
  }
  
  modal.style.display = 'block';
  
  // Load documents for current shipment
  await loadShipmentDocuments();
}

/**
 * Close the documents modal
 */
function closeDocumentsModal() {
  const modal = document.getElementById('documents-stage-modal');
  if (modal) {
    modal.style.display = 'none';
  }
}

/**
 * Load all documents for the current shipment
 */
async function loadShipmentDocuments() {
  const loadingDiv = document.getElementById('documents-loading');
  const gridDiv = document.getElementById('documents-grid');
  const emptyState = document.getElementById('documents-empty-state');
  
  try {
    // Show loading
    loadingDiv.style.display = 'block';
    emptyState.style.display = 'none';
    
    // Get shipment ID from URL or current state
    currentShipmentId = getCurrentShipmentId();
    
    if (!currentShipmentId) {
      throw new Error('No shipment ID found');
    }
    
    // Fetch documents from database
    const { data, error } = await supabase
      .from('document')
      .select(`
        *,
        uploader:uploaded_by (
          full_name,
          email
        )
      `)
      .eq('shipment_id', currentShipmentId)
      .order('uploaded_at', { ascending: false });
    
    if (error) throw error;
    
    allDocuments = data || [];
    
    // Hide loading
    loadingDiv.style.display = 'none';
    
    // Update document counts
    updateDocumentCounts();
    
    // Render documents
    renderDocuments(currentCategory);
    
  } catch (error) {
    console.error('Error loading documents:', error);
    loadingDiv.style.display = 'none';
    showDocumentsMessage('Failed to load documents: ' + error.message, 'error');
  }
}

/**
 * Update document counts in tabs
 */
function updateDocumentCounts() {
  const counts = {
    all: allDocuments.length,
    purchase: allDocuments.filter(d => getCategoryFromType(d.doc_type) === 'purchase').length,
    shipping: allDocuments.filter(d => getCategoryFromType(d.doc_type) === 'shipping').length,
    financial: allDocuments.filter(d => getCategoryFromType(d.doc_type) === 'financial').length,
    customs: allDocuments.filter(d => getCategoryFromType(d.doc_type) === 'customs').length,
    other: allDocuments.filter(d => getCategoryFromType(d.doc_type) === 'other').length
  };
  
  Object.keys(counts).forEach(category => {
    const countEl = document.getElementById(`count-${category}`);
    if (countEl) {
      countEl.textContent = counts[category];
    }
  });
}

/**
 * Get category from document type
 */
function getCategoryFromType(docType) {
  const categoryMap = {
    'proforma_invoice': 'purchase',
    'purchase_order': 'purchase',
    'commercial_invoice': 'purchase',
    'bill_of_lading': 'shipping',
    'packing_list': 'shipping',
    'certificate_of_origin': 'shipping',
    'shipping_instruction': 'shipping',
    'letter_of_credit': 'financial',
    'insurance_certificate': 'financial',
    'bank_charges': 'financial',
    'payment_receipt': 'financial',
    'ip_number': 'customs',
    'customs_declaration': 'customs',
    'release_order': 'customs',
    'enlistment_verification': 'customs',
    'quality_certificate': 'other',
    'phytosanitary_certificate': 'other',
    'fumigation_certificate': 'other',
    'other': 'other'
  };
  
  return categoryMap[docType] || 'other';
}

/**
 * Filter documents by category
 */
function filterDocuments(category) {
  currentCategory = category;
  
  // Update active tab
  document.querySelectorAll('.doc-tab-btn').forEach(btn => {
    btn.classList.remove('active');
    if (btn.dataset.category === category) {
      btn.classList.add('active');
    }
  });
  
  // Render filtered documents
  renderDocuments(category);
}

/**
 * Render documents in the grid
 */
function renderDocuments(category) {
  const gridDiv = document.getElementById('documents-grid');
  const emptyState = document.getElementById('documents-empty-state');
  const template = document.getElementById('document-card-template');
  
  if (!gridDiv || !template) return;
  
  // Clear existing documents (except empty state)
  gridDiv.querySelectorAll('.document-card').forEach(card => card.remove());
  
  // Filter documents
  let filteredDocs = allDocuments;
  if (category !== 'all') {
    filteredDocs = allDocuments.filter(d => getCategoryFromType(d.doc_type) === category);
  }
  
  // Apply search filter
  const searchTerm = document.getElementById('document-search')?.value?.toLowerCase() || '';
  if (searchTerm) {
    filteredDocs = filteredDocs.filter(d => 
      d.doc_type.toLowerCase().includes(searchTerm) ||
      d.file_url.toLowerCase().includes(searchTerm)
    );
  }
  
  // Show/hide empty state
  if (filteredDocs.length === 0) {
    emptyState.style.display = 'block';
  } else {
    emptyState.style.display = 'none';
    
    // Render each document
    filteredDocs.forEach(doc => {
      const card = template.content.cloneNode(true);
      const cardDiv = card.querySelector('.document-card');
      
      // Set data attributes
      cardDiv.dataset.docId = doc.id;
      cardDiv.dataset.category = getCategoryFromType(doc.doc_type);
      cardDiv.dataset.fileUrl = doc.file_url;
      
      // Set icon based on file type
      const icon = card.querySelector('.document-icon i');
      const fileExt = doc.file_url.split('.').pop().toLowerCase();
      icon.className = getFileIcon(fileExt);
      
      // Set document info
      const fileName = doc.file_url.split('/').pop();
      card.querySelector('.document-title').textContent = fileName;
      card.querySelector('.document-type').textContent = formatDocType(doc.doc_type);
      
      // Set metadata
      const uploadDate = new Date(doc.uploaded_at).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      });
      card.querySelector('.document-date').innerHTML = `<i class="fas fa-calendar"></i> ${uploadDate}`;
      
      const uploaderName = doc.uploader?.full_name || 'Unknown';
      card.querySelector('.document-uploader').innerHTML = `<i class="fas fa-user"></i> ${uploaderName}`;
      
      // Add to grid
      gridDiv.appendChild(card);
    });
  }
}

/**
 * Get file icon class based on extension
 */
function getFileIcon(extension) {
  const iconMap = {
    'pdf': 'fas fa-file-pdf',
    'doc': 'fas fa-file-word',
    'docx': 'fas fa-file-word',
    'xls': 'fas fa-file-excel',
    'xlsx': 'fas fa-file-excel',
    'jpg': 'fas fa-file-image',
    'jpeg': 'fas fa-file-image',
    'png': 'fas fa-file-image',
    'gif': 'fas fa-file-image'
  };
  
  return iconMap[extension] || 'fas fa-file';
}

/**
 * Format document type for display
 */
function formatDocType(docType) {
  return docType
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/**
 * Handle document upload
 */
document.getElementById('document-upload-form')?.addEventListener('submit', async function(e) {
  e.preventDefault();
  
  const formData = new FormData(e.target);
  const file = formData.get('document_file');
  const docType = formData.get('doc_type');
  const docCategory = formData.get('doc_category');
  const docNotes = formData.get('doc_notes');
  
  try {
    // Validate file size (10MB max)
    if (file.size > 10 * 1024 * 1024) {
      throw new Error('File size must be less than 10MB');
    }
    
    // Show loading
    showDocumentsMessage('Uploading document...', 'info');
    
    // Upload file to Supabase Storage
    const fileName = `${currentShipmentId}/${Date.now()}_${file.name}`;
    const { data: uploadData, error: uploadError } = await supabase
      .storage
      .from('shipment-docs')
      .upload(fileName, file);
    
    if (uploadError) throw uploadError;
    
    // Get public URL
    const { data: urlData } = supabase
      .storage
      .from('shipment-docs')
      .getPublicUrl(fileName);
    
    // Insert document record
    const { data: docData, error: docError } = await supabase
      .from('document')
      .insert({
        shipment_id: currentShipmentId,
        doc_type: docType,
        file_url: urlData.publicUrl,
        uploaded_by: (await supabase.auth.getUser()).data.user.id
      })
      .select()
      .single();
    
    if (docError) throw docError;
    
    // Success
    showDocumentsMessage('Document uploaded successfully!', 'success');
    
    // Reset form
    e.target.reset();
    
    // Reload documents
    await loadShipmentDocuments();
    
  } catch (error) {
    console.error('Error uploading document:', error);
    showDocumentsMessage('Failed to upload document: ' + error.message, 'error');
  }
});

/**
 * View document
 */
function viewDocument(button) {
  const card = button.closest('.document-card');
  const fileUrl = card.dataset.fileUrl;
  window.open(fileUrl, '_blank');
}

/**
 * Download document
 */
function downloadDocument(button) {
  const card = button.closest('.document-card');
  const fileUrl = card.dataset.fileUrl;
  
  // Create temporary link and trigger download
  const a = document.createElement('a');
  a.href = fileUrl;
  a.download = fileUrl.split('/').pop();
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

/**
 * Delete document
 */
async function deleteDocument(button) {
  const card = button.closest('.document-card');
  const docId = card.dataset.docId;
  const fileUrl = card.dataset.fileUrl;
  
  if (!confirm('Are you sure you want to delete this document?')) {
    return;
  }
  
  try {
    // Delete from database
    const { error: dbError } = await supabase
      .from('document')
      .delete()
      .eq('id', docId);
    
    if (dbError) throw dbError;
    
    // Delete from storage
    const filePath = fileUrl.split('/shipment-docs/')[1];
    if (filePath) {
      await supabase
        .storage
        .from('shipment-docs')
        .remove([filePath]);
    }
    
    // Success
    showDocumentsMessage('Document deleted successfully', 'success');
    
    // Reload documents
    await loadShipmentDocuments();
    
  } catch (error) {
    console.error('Error deleting document:', error);
    showDocumentsMessage('Failed to delete document: ' + error.message, 'error');
  }
}

/**
 * Download all documents
 */
async function downloadAllDocuments() {
  if (allDocuments.length === 0) {
    showDocumentsMessage('No documents to download', 'warning');
    return;
  }
  
  showDocumentsMessage('Preparing download...', 'info');
  
  // Download each document
  allDocuments.forEach((doc, index) => {
    setTimeout(() => {
      const a = document.createElement('a');
      a.href = doc.file_url;
      a.download = doc.file_url.split('/').pop();
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }, index * 500); // Stagger downloads to avoid browser blocking
  });
  
  showDocumentsMessage(`Downloading ${allDocuments.length} documents...`, 'success');
}

/**
 * Search documents
 */
document.getElementById('document-search')?.addEventListener('input', function(e) {
  renderDocuments(currentCategory);
});

/**
 * Show message in documents modal
 */
function showDocumentsMessage(message, type) {
  const messageDiv = document.getElementById('documents-modal-message');
  if (!messageDiv) return;
  
  messageDiv.textContent = message;
  messageDiv.className = `message ${type}`;
  messageDiv.style.display = 'block';
  
  setTimeout(() => {
    messageDiv.style.display = 'none';
  }, 5000);
}

/**
 * Get current shipment ID from URL or global state
 */
function getCurrentShipmentId() {
  // Try to get from URL parameter
  const urlParams = new URLSearchParams(window.location.search);
  let shipmentId = urlParams.get('id');
  
  // If not in URL, try to get from global state
  if (!shipmentId && window.currentShipmentData) {
    shipmentId = window.currentShipmentData.id;
  }
  
  return shipmentId;
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  // Close modal when clicking outside
  const modal = document.getElementById('documents-stage-modal');
  if (modal) {
    window.addEventListener('click', function(e) {
      if (e.target === modal) {
        closeDocumentsModal();
      }
    });
  }
});
