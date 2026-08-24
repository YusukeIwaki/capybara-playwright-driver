# frozen_string_literal: true

require 'spec_helper'

FILL_IN_LONG_TEXT_HTML = <<~HTML
  <!DOCTYPE html>
  <html>
  <body>
    <label for="body">Body</label>
    <textarea id="body" name="body" data-input-count="0" data-keyup-count="0"></textarea>
    <script>
      const body = document.getElementById('body');
      body.addEventListener('input', function() {
        body.dataset.inputCount = String(Number(body.dataset.inputCount) + 1);
      });
      body.addEventListener('keyup', function() {
        body.dataset.keyupCount = String(Number(body.dataset.keyupCount) + 1);
      });
    </script>
  </body>
  </html>
HTML

RSpec.describe '#fill_in', sinatra: true do
  before { sinatra.get('/long-text') { FILL_IN_LONG_TEXT_HTML } }

  it 'types replacement values longer than 1000 characters' do
    visit '/long-text'
    long_text = 'a' * 1_001

    fill_in 'Body', with: long_text

    textarea = find(:fillable_field, 'Body')
    expect(textarea.value).to eq(long_text)
    expect(textarea['data-keyup-count']).to eq(long_text.length.to_s)
  end

  it 'uses input events without keyup for non-US keyboard characters' do
    visit '/long-text'
    text = '更新済み'

    fill_in 'Body', with: text

    textarea = find(:fillable_field, 'Body')
    expect(textarea.value).to eq(text)
    expect(textarea['data-input-count']).to eq(text.length.to_s)
    expect(textarea['data-keyup-count']).to eq('0')
  end
end
