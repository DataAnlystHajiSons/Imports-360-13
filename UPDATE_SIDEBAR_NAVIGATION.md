# Update Sidebar Navigation - Add Document Requirements

## Files Already Updated:
✅ forecast.html
✅ admin-dashboard.html

## Files That Need Updates:

Find this block:
```html
<li>
  <a href="documents.html" class="nav-link">
    <i class="fas fa-file-alt icon"></i>
    <span class="text">Documents</span>
  </a>
</li>
```

Replace with:
```html
<li>
  <a href="#" class="nav-link has-submenu">
    <i class="fas fa-file-alt icon"></i>
    <span class="text">Documents</span>
    <span class="arrow"><i class="fas fa-chevron-down"></i></span>
  </a>
  <ul class="submenu">
    <li><a href="documents.html" class="nav-link"><span class="text">Document Management</span></a></li>
    <li><a href="admin-document-requirements.html" class="nav-link"><span class="text">Document Requirements</span></a></li>
  </ul>
</li>
```

## Pages to Update:
- [ ] documents.html
- [ ] verification-list.html
- [ ] shipment_tracker.html
- [ ] shipment-details.html
- [ ] shipment-documents.html
- [ ] product-details.html
- [ ] supplier-details.html
- [ ] supplier-payments.html
- [ ] supplier-shipment-responses.html
- [ ] bank-details.html
- [ ] bank-communication.html
- [ ] clearing-agent-details.html
- [ ] clearing-agent-communication.html
- [ ] warehouse-details.html
- [ ] logistic-cells.html
- [ ] send-freight-queries.html
- [ ] freight-query-response.html
- [ ] manage-freight-queries.html
- [ ] award-shipment.html
- [ ] admin-payment-terms.html
- [ ] admin-document-requirements.html (update its own sidebar too)

## Automated Update Script:

For each file, use Find & Replace:

**Find:**
```
        <li>
          <a href="documents.html" class="nav-link">
            <i class="fas fa-file-alt icon"></i>
            <span class="text">Documents</span>
          </a>
        </li>
```

**Replace:**
```
        <li>
          <a href="#" class="nav-link has-submenu">
            <i class="fas fa-file-alt icon"></i>
            <span class="text">Documents</span>
            <span class="arrow"><i class="fas fa-chevron-down"></i></span>
          </a>
          <ul class="submenu">
            <li><a href="documents.html" class="nav-link"><span class="text">Document Management</span></a></li>
            <li><a href="admin-document-requirements.html" class="nav-link"><span class="text">Document Requirements</span></a></li>
          </ul>
        </li>
```

## Note:
The existing JavaScript sidebar toggle logic already handles `.has-submenu` classes, so no JavaScript changes are needed.
