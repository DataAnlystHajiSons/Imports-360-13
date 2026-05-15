# Edge Function Update Guide: send-bank-email

## Purpose
Update the `send-bank-email` Supabase Edge Function to support CC (carbon copy) functionality for bank communications.

## Required Changes

### 1. Update Database Query to Fetch CC Emails

**Before:**
```javascript
const { data: communication, error: commError } = await supabase
  .from('bank_communication')
  .select(`
    *,
    bank_contact(contact_email, contact_name),
    bank(name)
  `)
  .eq('id', communication_id)
  .single();
```

**After:**
```javascript
const { data: communication, error: commError } = await supabase
  .from('bank_communication')
  .select(`
    *,
    cc_emails,
    bank_contact(contact_email, contact_name),
    bank(name)
  `)
  .eq('id', communication_id)
  .single();
```

### 2. Update Email Sending Logic

The exact implementation depends on your email service provider:

#### For SendGrid:

```javascript
const msg = {
  to: communication.bank_contact.contact_email,
  cc: communication.cc_emails || [], // Add CC emails
  from: 'noreply@yourcompany.com',
  subject: communication.email_subject,
  html: communication.email_body,
};

await sgMail.send(msg);
```

#### For Resend:

```javascript
const { data, error } = await resend.emails.send({
  from: 'noreply@yourcompany.com',
  to: communication.bank_contact.contact_email,
  cc: communication.cc_emails || [], // Add CC emails
  subject: communication.email_subject,
  html: communication.email_body,
});
```

#### For Nodemailer:

```javascript
const mailOptions = {
  from: 'noreply@yourcompany.com',
  to: communication.bank_contact.contact_email,
  cc: communication.cc_emails ? communication.cc_emails.join(', ') : '', // Join array
  subject: communication.email_subject,
  html: communication.email_body,
};

await transporter.sendMail(mailOptions);
```

#### For AWS SES:

```javascript
const params = {
  Source: 'noreply@yourcompany.com',
  Destination: {
    ToAddresses: [communication.bank_contact.contact_email],
    CcAddresses: communication.cc_emails || [], // Add CC emails
  },
  Message: {
    Subject: {
      Data: communication.email_subject,
    },
    Body: {
      Html: {
        Data: communication.email_body,
      },
    },
  },
};

await ses.sendEmail(params).promise();
```

### 3. Add Error Handling for CC Emails

```javascript
// Validate CC emails if present
if (communication.cc_emails && communication.cc_emails.length > 0) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const invalidEmails = communication.cc_emails.filter(email => !emailRegex.test(email));
  
  if (invalidEmails.length > 0) {
    console.error('Invalid CC emails found:', invalidEmails);
    // You might want to filter them out or return an error
    communication.cc_emails = communication.cc_emails.filter(email => emailRegex.test(email));
  }
}
```

### 4. Add Logging for CC Emails

```javascript
console.log('Sending email to:', communication.bank_contact.contact_email);
if (communication.cc_emails && communication.cc_emails.length > 0) {
  console.log('CC:', communication.cc_emails.join(', '));
}
```

## Complete Example Edge Function

```javascript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Import your email service (example: SendGrid)
// import sgMail from "@sendgrid/mail";

serve(async (req) => {
  try {
    const { communication_id } = await req.json();

    // Create Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Fetch communication details including CC emails
    const { data: communication, error: commError } = await supabase
      .from("bank_communication")
      .select(`
        *,
        cc_emails,
        bank_contact(contact_email, contact_name),
        bank(name),
        sent_by:app_user(full_name, email)
      `)
      .eq("id", communication_id)
      .single();

    if (commError) {
      throw new Error(`Failed to fetch communication: ${commError.message}`);
    }

    if (!communication.bank_contact?.contact_email) {
      throw new Error("No bank contact email found");
    }

    // Validate and filter CC emails
    let ccEmails = [];
    if (communication.cc_emails && communication.cc_emails.length > 0) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      ccEmails = communication.cc_emails.filter(email => emailRegex.test(email));
      
      if (ccEmails.length !== communication.cc_emails.length) {
        console.warn("Some CC emails were invalid and filtered out");
      }
    }

    // Log email details
    console.log("Sending email:");
    console.log("  To:", communication.bank_contact.contact_email);
    if (ccEmails.length > 0) {
      console.log("  CC:", ccEmails.join(", "));
    }
    console.log("  Subject:", communication.email_subject);

    // Send email using your email service
    // Example with SendGrid:
    /*
    sgMail.setApiKey(Deno.env.get("SENDGRID_API_KEY")!);
    
    const msg = {
      to: communication.bank_contact.contact_email,
      cc: ccEmails,
      from: "noreply@yourcompany.com",
      subject: communication.email_subject,
      html: communication.email_body,
      replyTo: communication.sent_by.email,
    };

    await sgMail.send(msg);
    */

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "Email sent successfully",
        cc_count: ccEmails.length 
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 200,
      }
    );

  } catch (error) {
    console.error("Error sending email:", error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      {
        headers: { "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
```

## Deployment Steps

1. **Run Database Migration:**
   ```bash
   psql -h your-db-host -d your-db -f add_cc_emails_to_bank_communication.sql
   ```

2. **Update Edge Function:**
   - Modify your `send-bank-email` function code
   - Test locally if possible
   - Deploy to Supabase:
     ```bash
     supabase functions deploy send-bank-email
     ```

3. **Test the Integration:**
   - Send a test communication with CC emails
   - Verify CC recipients receive the email
   - Check logs for any errors

## Testing Checklist

- [ ] Database migration completed
- [ ] Edge function updated and deployed
- [ ] Send email without CC (ensure backward compatibility)
- [ ] Send email with single CC recipient
- [ ] Send email with multiple CC recipients
- [ ] Verify CC recipients receive emails
- [ ] Check email headers confirm CC addresses
- [ ] Test error handling with invalid CC emails
- [ ] Verify logging shows CC recipients
- [ ] Check production edge function logs

## Troubleshooting

### Issue: CC emails not received
**Solution:** Check email service provider logs, verify CC array format is correct

### Issue: Invalid email format errors
**Solution:** Add email validation in edge function (shown above)

### Issue: null or undefined cc_emails
**Solution:** Use `communication.cc_emails || []` to handle null/undefined cases

### Issue: Email service rejects CC array
**Solution:** Some services need comma-separated string: `cc_emails.join(', ')`

## Notes

- CC emails are optional - ensure backward compatibility
- Always validate CC emails before sending
- Log CC recipients for audit trail
- Consider rate limits when CC'ing many recipients
- Test with your specific email service provider
