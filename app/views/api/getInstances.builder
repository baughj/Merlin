xml.instruct!
xml.merlin do
  xml.instances do
  @instances.each { |i|
    xml.instance do
      xml.id i.instance_id
      xml.type i.instance_type
      xml.active i.active
      xml.hostname i.hostname
    end
  }
  end
end
