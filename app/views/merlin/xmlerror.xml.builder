xml.instruct!
xml.merlin do
  xml.requestError do
    xml.action @action
    xml.error flash[:error]
  end
end

