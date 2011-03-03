xml.instruct!
xml.merlin do
  xml.action @action
  xml.result @result
  xml.message @message
  if @instance then
    xml.requestid @instance.request_id
  end
end
