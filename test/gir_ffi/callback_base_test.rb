# frozen_string_literal: true

require 'gir_ffi_test_helper'

describe GirFFI::CallbackBase do
  describe '.store_callback' do
    it 'stores the passed in proc in CALLBACKS' do
      dummy_proc = 'some-callback'
      GirFFI::CallbackBase.store_callback dummy_proc
      GirFFI::CallbackBase::CALLBACKS[dummy_proc.object_id].must_equal dummy_proc
    end
  end

  describe '.drop_callback' do
    it 'removes the corresponding proc from CALLBACKS' do
      dummy_proc = 'some-callback'
      GirFFI::CallbackBase.store_callback dummy_proc
      GirFFI::CallbackBase.drop_callback dummy_proc
      GirFFI::CallbackBase::CALLBACKS[dummy_proc.object_id].must_be_nil
    end
  end
end
