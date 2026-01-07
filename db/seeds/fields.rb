# frozen_string_literal: true

{
  'Account' => [
    {
      params: { label: 'General Information', hint: '' },
      fields: [
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' }
      ]
    },
    {
      params: { label: 'Contact Information', hint: '' },
      fields: []
    }
  ],
  'Campaign' => [
    {
      params: { label: 'General Information', hint: '' },
      fields: [
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' }
      ]
    },
    {
      params: { label: 'Contact Information', hint: '' },
      fields: []
    }
  ],
  'Contact' => [
    {
      params: { label: 'General Information', hint: '' },
      fields: []
    },
    {
      params: { label: 'Extra Information', hint: '' },
      fields: []
    },
    {
      params: { label: 'Web presence', hint: '' },
      fields: []
    }
  ],
  'Lead' => [
    {
      params: { label: 'General Information', hint: '' },
      fields: [
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' }
      ]
    },
    {
      params: { label: 'Contact Information', hint: '' },
      fields: []
    }
  ],
  'Opportunity' => [
    {
      params: { label: 'General Information', hint: '' },
      fields: [
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' },
        { field_type: '', name: '', label: '', required: '' }
      ]
    },
    {
      params: { label: 'Contact Information', hint: '' },
      fields: []
    }
  ]
}.each_with_index do |(klass_name, groups), group_position|
  groups.each do |group|
    field_group = FieldGroup.create group[:params].merge(klass_name: klass_name, position: group_position)
    group[:fields].each_with_index do |params, field_position|
      Field.create params.merge(field_group: field_group, position: field_position)
    end
  end
end
