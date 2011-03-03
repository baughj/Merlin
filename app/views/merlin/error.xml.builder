xml.instruct!
xml.merlin do
  xml.action @action
  if flash[:error]
    xml.result "FAIL"
    xml.message flash[:error].to_sentence
  else
    xml.result "SUCCESS"
    xml.message @message
    if @instance then
      xml.requestid @instance.request_id
    end
  end
end
