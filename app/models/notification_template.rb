class NotificationTemplate < ActiveRecord::Base

  def process(binding)
    {'subject' => ERB.new(self.subject).result(binding),
      'body' => ERB.new(self.template).result(binding)}
  end

end
