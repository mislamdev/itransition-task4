# Reference images of the task

## `login-form-example.png`

The login form example that belongs to the task description ("This is a login
form"). It is kept here as the reference of the design of the sign in form.

**How the application relates to it:**

* the form has the same elements — e-mail, password, the sign in button and the
  link to the registration form;
* the application is deliberately *boring and business like*, as the task asks
  for ("look like a business-oriented professional app (boring, but consistent
  and accurate)"): a centred card on a plain surface, no wallpaper, no
  animation, no image behind the form;
* therefore the illustration is NOT copied pixel by pixel — the layout of the
  sign in form is the one of `app/views/sessions/new.html.erb`.

## `table-example.png`

The table example that belongs to the task description ("This is example of a
table with toolbar"). The task says explicitly: *"you are not required to
implement sparklines with previous user activity"*.

**The elements of the reference and where they are in the application:**

| Element of the reference | In the application |
|---|---|
| the toolbar with **Block** (text), **Unblock** (icon), **Delete** (icon) | `app/views/users/index.html.erb` — the card header above the table, the buttons are always visible and only their state changes |
| the checkbox in the header without a label | the same — it selects and deselects all the rows |
| the **Filter** field on the right of the toolbar | the search field of the toolbar (it belongs to the filter form, not to the selection form) |
| the name in the first column, the position below it | the name cell shows the name and the position as a second line |
| the **Status** as a text, a blocked row is dimmed | the status is a text with a small coloured dot, a blocked row is dimmed and struck through |
| **Last seen** as a relative time ("5 minutes ago") with a tooltip with the exact time | the last login and the last activity are relative times, the tooltip shows the exact timestamp |
| the small sparklines | NOT implemented - the task does not require them |
