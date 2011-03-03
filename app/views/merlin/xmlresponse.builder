xml.instruct!
xml.merlin do
  xml.response do
    xml.action @action
    @res.each { |key, value| 
      xml.object do
        xml.id key
	xml.result value[0]
	xml.resultDetail value[1]
      end
    }	
  end
end
