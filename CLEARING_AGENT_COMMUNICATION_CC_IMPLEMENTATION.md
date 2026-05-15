# Clearing Agent Communication with CC Functionality - Complete Implementation

## Overview
Comprehensive clearing agent communication system with built-in CC (carbon copy) functionality, allowing users to send emails to clearing agents with stakeholder notifications for shipments.

## Implementation Summary

This implementation includes:
- ✅ Database tables for clearing agent communications
- ✅ Frontend page with CC email functionality
- ✅ Edge function for sending emails with CC support
- ✅ Document attachment support
- ✅ Communication history tracking
- ✅ Complete email validation

## Files Created

### 1. Database Migration: `create_clearing_agent_communication_table.sql`

Creates two tables:

#### Table: `clearing_agent_communication`
Stores all email communications sent to clearing agents.

**Columns:**
- `id` (uuid, primary key)
- `shipment_id` (uuid, foreign key → shipment)
- `clearing_agent_id` (uuid, foreign key → clearing_agent)
- `sent_by` (uuid, foreign key → app_user)
- `sent_at` (timestamp with time zone)
- `email_subject` (text)
- `email_body` (text)
- `cc_emails` (text[]) - **Array of stakeholder emails**
- `status` (text)

**Indexes:**
- `idx_clearing_agent_communication_shipment_id`
- `idx_clearing_agent_communication_clearing_agent_id`

#### Table: `clearing_agent_communication_documents`
Junction table for document attachments.

**Columns:**
- `communication_id` (uuid, foreign key → clearing_agent_communication)
- `document_id` (uuid, foreign key → document)

### 2. Frontend: `clearing-agent-communication.html`

Complete communication interface with CC functionality.

#### Features:
- **Clearing Agent Selection**: Dropdown with all clearing agents
- **Email Auto-Fill**: Email field auto-populates on agent selection
- **CC Email Tags**: Tag-based interface for multiple stakeholders
- **Document Attachments**: Checkbox list of shipment documents
- **Communication History**: Table showing all past communications with CC recipients
- **Real-time Validation**: Email format validation with error messages

#### UI Components:
```html
<!-- CC Email Input with Tags -->
<div class="cc-container">
  <div class="cc-tag">
    stakeholder@example.com
    <span class="remove-cc">×</span>
  </div>
  <input type="text" class="cc-input-field" placeholder="Enter email...">
</div>
```

#### JavaScript Functions:
- `validateEmail(email)` - Email format validation
- `addCCEmail(email)` - Add email with duplicate prevention
- `removeCCEmail(email)` - Remove email from list
- `renderCCTags()` - Visual tag rendering
- `showCCError(message)` - Error message display
- `loadClearingAgents()` - Fetch clearing agents from DB
- `loadShipmentDocuments()` - Fetch shipment documents
- `loadCommunicationHistory()` - Display past communications
- `handleSendCommunication()` - Form submission with CC support

### 3. Edge Function: `supabase/functions/send-clearing-agent-email/index.ts`

Handles email sending to clearing agents with CC support.

#### Features:
- Fetches communication data with CC emails
- Validates CC email addresses
- Filters invalid emails with warnings
- Includes CC in Resend API call
- Comprehensive logging
- Returns CC count in response

#### Key Code Sections:

**Fetch with CC Emails:**
```typescript
const { data: commData } = await supabaseAdmin
  .from('clearing_agent_communication')
  .select(`
    email_subject,
    email_body,
    cc_emails,
    clearing_agent ( id, name, contact_email ),
    clearing_agent_communication_documents (
      document ( file_url, doc_type )
    )
  `)
  .eq('id', communication_id)
  .single()
```

**Email Validation:**
```typescript
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
ccEmails = commData.cc_emails.filter((email: string) => 
  emailRegex.test(email)
)
```

**Send with CC:**
```typescript
const emailPayload: any = {
  from: 'Imports 360 <onboarding@resend.dev>',
  to: [recipientEmail],
  cc: ccEmails, // CC array
  subject: commData.email_subject,
  html: commData.email_body,
  attachments: attachments,
}
```

## Data Flow

### 1. User Sends Communication
```
User fills form → Adds CC emails → Selects documents → Submits
    ↓
Frontend validates CC emails
    ↓
Insert into clearing_agent_communication table (with cc_emails array)
    ↓
Insert into clearing_agent_communication_documents (document links)
    ↓
Invoke send-clearing-agent-email edge function
    ↓
Edge function fetches data and sends email via Resend
    ↓
Success response shown to user
```

### 2. Communication History Display
```
Page loads → Fetch clearing_agent_communication records
    ↓
Display in table with:
  - Sent date
  - Clearing agent name
  - CC recipients (comma-separated)
  - Subject
  - Status
```

## Database Schema Integration

The new tables integrate with existing schema:

```
shipment (1) ──── (N) clearing_agent_communication
                        │
                        ├─── cc_emails (text[])
                        │
                        └─── (M) clearing_agent_communication_documents (N) ──── document

clearing_agent (1) ──── (N) clearing_agent_communication

app_user (1) ──── (N) clearing_agent_communication (sent_by)
```

## Usage Guide

### For Users:

1. **Navigate to Communication Page**
   ```
   clearing-agent-communication.html?id=<shipment_id>
   ```

2. **Fill Communication Form**
   - Select clearing agent (email auto-fills)
   - Enter subject line
   - Add CC stakeholders (one at a time, press Enter)
   - Write email body
   - Select documents to attach (optional)

3. **Manage CC Emails**
   - Type email and press Enter or comma
   - Click × on tag to remove
   - Press Backspace on empty field to remove last email

4. **Send Communication**
   - Click "Send Email" button
   - Edge function sends email with CC
   - Success message confirms delivery

5. **View History**
   - See all past communications
   - View CC recipients for each communication
   - Check communication status

### For Developers:

#### Deploy Database:
```bash
psql -h HOST -U postgres -d postgres -f create_clearing_agent_communication_table.sql
```

#### Deploy Edge Function:
```bash
supabase functions deploy send-clearing-agent-email
```

#### Test the Feature:
```javascript
// Test database insert
const { data, error } = await supabase
  .from('clearing_agent_communication')
  .insert({
    shipment_id: 'shipment-uuid',
    clearing_agent_id: 'agent-uuid',
    sent_by: 'user-uuid',
    email_subject: 'Test Subject',
    email_body: 'Test Body',
    cc_emails: ['stakeholder1@example.com', 'stakeholder2@example.com'],
    status: 'sent'
  })
```

## Deployment Checklist

### Step 1: Database
- [ ] Run `create_clearing_agent_communication_table.sql`
- [ ] Verify tables created successfully
- [ ] Check indexes created
- [ ] Verify foreign key constraints

### Step 2: Frontend
- [ ] Deploy `clearing-agent-communication.html`
- [ ] Verify page loads without errors
- [ ] Test clearing agent selection
- [ ] Test CC email adding/removing
- [ ] Test form submission

### Step 3: Edge Function
- [ ] Deploy `send-clearing-agent-email`
- [ ] Verify function in Supabase dashboard
- [ ] Check environment variables (RESEND_API_KEY)
- [ ] Test function invocation

### Step 4: Integration Testing
- [ ] Send email without CC (backward compatibility)
- [ ] Send email with single CC
- [ ] Send email with multiple CCs
- [ ] Verify all recipients receive email
- [ ] Check communication history displays CC
- [ ] Verify document attachments work
- [ ] Test email validation

## Features Comparison

| Feature | Bank Communication | Clearing Agent Communication |
|---------|-------------------|----------------------------|
| CC Emails | ✅ Yes | ✅ Yes |
| Tag-based Input | ✅ Yes | ✅ Yes |
| Email Validation | ✅ Yes | ✅ Yes |
| Document Attachments | ✅ Yes | ✅ Yes |
| Communication History | ✅ Yes | ✅ Yes |
| Auto-email Fill | ❌ No (contact select) | ✅ Yes (agent select) |
| Edge Function | send-bank-email | send-clearing-agent-email |

## CSS Styling

Reuses the same CC styling as bank communication:
- Gradient orange tags (#F59E0B → #FBB124)
- Focus states with shadow
- Responsive flexbox container
- Remove buttons with hover effects
- Error messages with fade animation

## Security Considerations

1. **Email Validation**: Frontend and backend validate email format
2. **Authentication**: Requires logged-in user
3. **Authorization**: Uses Supabase RLS policies
4. **Cascade Deletes**: ON DELETE CASCADE for data integrity
5. **Input Sanitization**: Supabase handles SQL injection prevention

## Performance Optimizations

1. **Indexes**: On shipment_id and clearing_agent_id for fast queries
2. **Batch Operations**: Document attachments inserted in batch
3. **Efficient Queries**: Use `.select()` to fetch only needed data
4. **Array Storage**: CC emails stored as PostgreSQL array (efficient)

## Error Handling

### Frontend:
- Invalid email format → Show error for 3 seconds
- Duplicate email → Show error message
- No clearing agent selected → Alert on submit
- Network errors → Alert with error message

### Edge Function:
- Invalid email in array → Filter out, log warning
- Missing recipient → Throw error
- Resend API error → Return 500 with message
- Missing communication_id → Throw error

## Future Enhancements

1. **Email Templates**: Pre-filled templates for common messages
2. **Stakeholder Picker**: Select from database of stakeholders
3. **Auto-suggest**: Suggest stakeholders based on shipment
4. **Group CC Lists**: Save and reuse CC groups
5. **BCC Support**: Add blind carbon copy field
6. **Read Receipts**: Track when emails are opened
7. **Reply Tracking**: Link replies to original communication
8. **Bulk Communications**: Send to multiple clearing agents at once

## Troubleshooting

### Issue: CC emails not showing in history
**Solution:** Clear browser cache, verify database migration ran

### Issue: Edge function not found
**Solution:** Deploy with `supabase functions deploy send-clearing-agent-email`

### Issue: Email not sending
**Solution:** Check Resend API key in environment variables

### Issue: Invalid email not filtered
**Solution:** Check edge function logs for warnings

### Issue: Clearing agent email not showing
**Solution:** Ensure clearing_agent table has contact_email filled

## Testing SQL Queries

```sql
-- View all communications with CC
SELECT 
  cac.id,
  cac.email_subject,
  cac.cc_emails,
  cac.sent_at,
  ca.name as clearing_agent,
  s.reference_code as shipment
FROM clearing_agent_communication cac
LEFT JOIN clearing_agent ca ON cac.clearing_agent_id = ca.id
LEFT JOIN shipment s ON cac.shipment_id = s.id
ORDER BY cac.sent_at DESC
LIMIT 10;

-- Count communications by clearing agent
SELECT 
  ca.name,
  COUNT(cac.id) as communication_count,
  COUNT(CASE WHEN cac.cc_emails IS NOT NULL THEN 1 END) as with_cc_count
FROM clearing_agent ca
LEFT JOIN clearing_agent_communication cac ON ca.id = cac.clearing_agent_id
GROUP BY ca.name
ORDER BY communication_count DESC;
```

## Support

For issues:
1. Check edge function logs: `supabase functions logs send-clearing-agent-email --tail`
2. Check browser console for frontend errors
3. Verify database tables exist
4. Check Resend dashboard for email delivery
5. Review RLS policies if permission errors occur

## Summary

Complete clearing agent communication system with:
- ✅ Database tables created
- ✅ Frontend page with CC functionality
- ✅ Edge function for email sending
- ✅ Full documentation
- ✅ Ready for deployment

**Next Step:** Follow deployment checklist to deploy to production!
