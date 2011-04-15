class EmailNotifier < ActionMailer::Base

  def send_notification(recipient, subj, text)
    recipients recipient
    from AppConfig.merlin_email_address
    subject subj
    body text
  end

end
