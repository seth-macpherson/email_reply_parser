# encoding: UTF-8
require 'rubygems'
require 'test/unit'
require 'pathname'
require 'pp'

dir = Pathname.new File.expand_path(File.dirname(__FILE__))
require dir + '..' + 'lib' + 'tr_email_reply_parser'

EMAIL_FIXTURE_PATH = dir + 'emails'

class EmailReplyParserTest < Test::Unit::TestCase
  def test_does_not_modify_input_string
    original = "The Quick Brown Fox Jumps Over The Lazy Dog"
    EmailReplyParser.read original
    assert_equal "The Quick Brown Fox Jumps Over The Lazy Dog", original
  end

  def test_reads_simple_body
    reply = email(:email_1_1)
    assert_equal 3, reply.fragments.size

    assert reply.fragments.none? { |f| f.quoted? }
    assert_equal [false, true, true],
      reply.fragments.map { |f| f.signature? }
    assert_equal [false, true, true],
      reply.fragments.map { |f| f.hidden? }

    assert_equal "Hi folks

What is the best way to clear a Riak bucket of all key, values after
running a test?
I am currently using the Java HTTP API.\n", reply.fragments[0].to_s

    assert_equal "-Abhishek Kona\n\n", reply.fragments[1].to_s
  end

  def test_reads_top_post
    reply = email(:email_1_3)
    assert_equal 5, reply.fragments.size

    assert_equal [false, false, true, false, false],
      reply.fragments.map { |f| f.quoted? }
    assert_equal [false, true, true, true, true],
      reply.fragments.map { |f| f.hidden? }
    assert_equal [false, true, false, false, true],
      reply.fragments.map { |f| f.signature? }

    assert_match /^Oh thanks.\n\nHaving/, reply.fragments[0].to_s
    assert_match /^-A/, reply.fragments[1].to_s
    assert_match /^On [^\:]+\:/, reply.fragments[2].to_s
    assert_match /^_/, reply.fragments[4].to_s
  end

  def test_reads_bottom_post
    reply = email(:email_1_2)
    assert_equal 6, reply.fragments.size

    assert_equal [false, true, false, true, false, false],
      reply.fragments.map { |f| f.quoted? }
    assert_equal [false, false, false, false, false, true],
      reply.fragments.map { |f| f.signature? }
    assert_equal [false, false, false, true, true, true],
      reply.fragments.map { |f| f.hidden? }

    assert_equal "Hi,", reply.fragments[0].to_s
    assert_match /^On [^\:]+\:/, reply.fragments[1].to_s
    assert_match /^You can list/, reply.fragments[2].to_s
    assert_match /^> /, reply.fragments[3].to_s
    assert_match /^_/, reply.fragments[5].to_s
  end

  def test_recognizes_date_string_above_quote
    reply = email :email_1_4

    assert_match /^Awesome/, reply.fragments[0].to_s
    assert_match /^On/,      reply.fragments[1].to_s
    assert_match /Loader/,   reply.fragments[1].to_s
  end

  def test_a_complex_body_with_only_one_fragment
    reply = email :email_1_5

    assert_equal 1, reply.fragments.size
  end

  def test_reads_email_with_correct_signature
    reply = email :correct_sig

    assert_equal 2, reply.fragments.size
    assert_equal [false, false], reply.fragments.map { |f| f.quoted? }
    assert_equal [false, true], reply.fragments.map { |f| f.signature? }
    assert_equal [false, true], reply.fragments.map { |f| f.hidden? }
    assert_match /^--\nrick/, reply.fragments[1].to_s
  end

  def test_reads_email_containing_hyphens
    reply = email :email_hyphens
    assert_equal 1, reply.fragments.size
    body = reply.fragments[0].to_s
    assert_match /^Keep in mind/, body
    assert_match /their physical exam.$/, body
  end

  def test_arbitrary_hypens_and_underscores
    assert_one_signature = lambda do |reply|
      assert_equal 2, reply.fragments.size
      assert_equal [false, true], reply.fragments.map { |f| f.hidden? }
    end

    reply = EmailReplyParser.read "here __and__ now.\n\n---\nSandro"
    assert_one_signature.call reply

    reply = EmailReplyParser.read "--okay\n\n-Sandro"
    assert_one_signature.call reply

    reply = EmailReplyParser.read "__okay\n\n-Sandro"
    assert_one_signature.call reply

    reply = EmailReplyParser.read "--1337\n\n-Sandro"
    assert_one_signature.call reply

    reply = EmailReplyParser.read "__1337\n\n-Sandro"
    assert_one_signature.call reply

    reply = EmailReplyParser.read "data -- __ foo\n\n-Sandro"
    assert_one_signature.call reply
  end

  def test_email_body_is_signature
    reply = EmailReplyParser.parse_reply "-- \nLes Hill\nleshill@gmail.com"
    assert_equal "", reply

    reply = EmailReplyParser.parse_reply "From: abc\nTo: Les Hill\nDate: 31/01/2013\nSubject: foo"
    assert_equal "", reply

    reply = EmailReplyParser.parse_reply "On Fri, Feb 24, 2012 at 10:19 AM, <boris@example.com> wrote:\n\n> hello"
    assert_equal "", reply
  end

  def test_deals_with_multiline_reply_headers
    reply = email :email_1_6

    assert_match /^I get/,   reply.fragments[0].to_s
    assert_match /^On/,      reply.fragments[1].to_s
    assert_match /Was this/, reply.fragments[1].to_s
  end

  def test_deals_with_windows_line_endings
    reply = email :email_1_7

    assert_match /:\+1:/,     reply.fragments[0].to_s
    assert_match /^On/,       reply.fragments[1].to_s
    assert_match /Steps 0-2/, reply.fragments[1].to_s
  end

  def test_parse_out_date_name_email_header
    assert_equal "Hello", visible_text(:email_1_8)
  end

  def test_signature_prefixed_by_whitespace
    assert_equal "Foo", visible_text(:email_1_9)
  end

  def test_returns_only_the_visible_fragments_as_a_string
    reply = email(:email_2_1)
    assert_equal reply.fragments.select{|r| !r.hidden?}.map{|r| r.to_s}.join("\n").rstrip, reply.visible_text
  end

  def test_parse_out_just_top_for_outlook_reply
    assert_equal "Outlook with a reply", visible_text(:email_2_1)
  end

  def test_parse_out_just_top_for_outlook_with_reply_directly_above_line
    assert_equal "Outlook with a reply directly above line", visible_text(:email_2_2)
  end

  def test_parse_out_just_top_for_windows_8_mail
    assert_equal "This one is from Windows 8 Mail (preview).", visible_text(:email_2_3)
  end

  def test_parse_out_just_top_for_outlook_2007
    assert_equal "Here's one from Outlook 2007.", visible_text(:email_2_4)
  end

  def test_parse_out_just_top_for_more_outlook_2013
    assert_equal "One from Outlook 2013?", visible_text(:email_2_5)
  end

  def test_parse_out_just_top_for_hotmail_reply
    assert_equal "Reply from the hottest mail.", visible_text(:email_2_6)
  end

  def test_parse_original_message
    assert_equal "Foo", visible_text(:email_2_7)
  end

  def test_parse_weird_signature
    assert_equal "Hello", visible_text(:email_2_8)
  end

  def test_parse_weird_signature_by_name
    body = IO.read EMAIL_FIXTURE_PATH.join("email_2_9.txt").to_s
    expected_body = "Hello"
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "Rick Olson <rick.olson@example.com>")
  end

  def test_parse_out_sent_from_iPhone
    assert_equal "Here is another email", visible_text(:email_iPhone)
  end

  def test_parse_out_sent_from_BlackBerry
    assert_equal "Here is another email", visible_text(:email_BlackBerry)
  end

  def test_parse_out_send_from_multiword_mobile_device
    assert_equal "Here is another email", visible_text(:email_multi_word_sent_from_my_mobile_device)
  end

  def test_do_not_parse_out_send_from_in_regular_sentence
    expected = "Here is another email\n\nSent from my desk, is much easier then my mobile phone."
    assert_equal expected, visible_text(:email_sent_from_my_not_signature)
  end

  def test_retains_bullets
    expected = "test 2 this should list second\n\nand have spaces\n\nand retain this formatting\n\n\n   - how about bullets\n   - and another"
    assert_equal expected, visible_text(:email_bullets)
  end

  def test_parse_reply
    body = IO.read EMAIL_FIXTURE_PATH.join("email_1_2.txt").to_s
    assert_equal EmailReplyParser.read(body).visible_text, EmailReplyParser.parse_reply(body)
  end

  def test_parse_out_signature_using_from_name
    body = IO.read EMAIL_FIXTURE_PATH.join("email_no_signature_deliminator.txt").to_s
    expected_body = "I don't like putting any delimiator in my signature because I think that is cool.\n\nReally it is."
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "Jim Smith <john.smith@gmail.com>")
  end

 def test_parse_out_signature_using_from_name_different_case
    body = IO.read EMAIL_FIXTURE_PATH.join("email_no_signature_deliminator.txt").to_s
    expected_body = "I don't like putting any delimiator in my signature because I think that is cool.\n\nReally it is."
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "jim smith <john.smith@gmail.com>")
  end


  def test_parse_out_signature_using_from_name_last_then_first
    body = IO.read EMAIL_FIXTURE_PATH.join("email_no_signature_deliminator.txt").to_s
    expected_body = "I don't like putting any delimiator in my signature because I think that is cool.\n\nReally it is."
    assert_equal expected_body, EmailReplyParser.parse_reply(body, '"Smith, Jim" <john.smith@gmail.com>')
  end

  def test_parse_out_signature_using_from_name_when_middle_initial_is_in_signature
    body = IO.read EMAIL_FIXTURE_PATH.join("email_no_signature_deliminator_adds_a_middle_initial.txt").to_s
    expected_body = "I don't like putting any delimiator in my signature because I think that is cool.\n\nReally it is."
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "Jim Smith <john.smith@gmail.com>")
  end

  def test_that_a_sentence_with_my_name_in_it_does_not_become_a_signature
    body = IO.read EMAIL_FIXTURE_PATH.join("email_mentions_own_name.txt").to_s
    expected_body = "Hi,\n\nMy name is Jim Smith and I had a question.\n\nWhat do you do?"
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "Jim Smith <john.smith@gmail.com>")
  end

  def test_simple_email_with_reply
    body = IO.read EMAIL_FIXTURE_PATH.join("email_was_showing_as_nothing_visible.txt").to_s
    expected_body = "On Friday, one achievement I had was learning a new technology that allows us
to keep UI elements and events separated from the software on the
server side, which should allow for more flexible UI code and
decreased chances of code becoming a swarm of angry hornets.  I've
been transparent about the initial increased development time while
learning the technology."

    assert_equal expected_body, EmailReplyParser.parse_reply(body)
  end

  def test_2nd_paragraph_starts_with_on
    body = IO.read EMAIL_FIXTURE_PATH.join("email_2nd_paragraph_starting_with_on.txt").to_s
    expected_body = "This emails tests that multiline header fix isn't catching things it shouldn't.

On friday when I tried it didn't work as expect.

This line would have been considered part of the header line."
    assert_equal expected_body, EmailReplyParser.parse_reply(body)
  end

  def test_from_email_in_quote_header
    body = IO.read EMAIL_FIXTURE_PATH.join("email_from_address_in_quote_header.txt").to_s
    expected_body = "I have gained valuable experience from working with students from other cultures. They bring a significantly different perspective to the work we do. I have also had the opportunity to practice making myself very clear in discussion, so that everyone understands. I've also seen how different our culture is to them, in their reactions to what I think is a normal approach to assignments, and to life in general."
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "shelly@example.com")
  end

  def test_do_not_make_any_line_with_from_address_quote_heading
    body = IO.read EMAIL_FIXTURE_PATH.join("email_mentions_own_email_address.txt").to_s
    expected_body = "Hi,\n\nMy email is john.smith@gmail.com and I had a question.\n\nWhat do you do?"
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "Jim Smith <john.smith@gmail.com>")
  end

  def test_from_name_in_quote_header
    body = IO.read EMAIL_FIXTURE_PATH.join("email_from_name_in_quote_header.txt").to_s
    expected_body = "I have gained valuable experience from working with students from other cultures. They bring a significantly different perspective to the work we do. I have also had the opportunity to practice making myself very clear in discussion, so that everyone understands. I've also seen how different our culture is to them, in their reactions to what I think is a normal approach to assignments, and to life in general."
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "Smith, Shelly <shelly@example.com>")
  end

  def test_multiline_quote_header_from_first
    body = IO.read EMAIL_FIXTURE_PATH.join("email_multiline_quote_header_from_first.txt").to_s
    expected_body = "I have gained valuable experience from working with students from other cultures. They bring a significantly different perspective to the work we do. I have also had the opportunity to practice making myself very clear in discussion, so that everyone understands. I've also seen how different our culture is to them, in their reactions to what I think is a normal approach to assignments, and to life in general."
    assert_equal expected_body, EmailReplyParser.parse_reply(body, "Smith, Shelly <shelly@example.com>")
  end

  def test_multiline_quote_header_none
    text = visible_text(:email_multiline_quote_header_none)
    assert_match /Foo/, text
    assert_match /THE END!/, text
  end

  def test_multiline_quote_header_from_to_date_subject
    assert_equal "Foo!", visible_text(:email_multiline_quote_header_from_to_date_subject)
  end

  def test_multiline_quote_header_from_replyto_date_to_subject
    assert_equal "Foo!", visible_text(:email_multiline_quote_header_from_replyto_date_to_subject)
  end

  def test_multiline_quote_header_pt_br
    assert_equal "Foo-pt-br", visible_text(:email_multiline_quote_header_pt_br)
  end

  def test_multiline_quote_header_es_mx
    assert_equal "Foo!", visible_text(:email_multiline_quote_header_es_mx)
  end

  def test_multiline_quote_header_fr
    assert_equal "Foo!", visible_text(:email_multiline_quote_header_fr)
  end

  def test_multiline_quote_header_with_cc
    assert_equal "Foo", visible_text(:email_multiline_quote_header_with_cc)
  end

  def test_multiline_quote_header_with_multiline_headers
    assert_equal "Foo", visible_text(:email_multiline_quote_header_with_multiline_headers)
  end

  def test_multiline_quote_header_with_asterisks
    assert_equal "Outlook with a reply", visible_text(:email_multiline_quote_header_with_asterisks)
  end

  def test_parsing_name_from_address
    address = "Bob Jones <bob@gmail.com>"
    email = EmailReplyParser::Email.new
    assert_equal "Bob Jones", email.send(:parse_name_from_address, address)
  end

  def test_parsing_name_from_address_with_double_quotes
    address = "\"Bob Jones\" <bob@gmail.com>"
    email = EmailReplyParser::Email.new
    assert_equal "Bob Jones", email.send(:parse_name_from_address, address)
  end

  def test_parsing_name_from_address_with_single_quotes
    address = "'Bob Jones' <bob@gmail.com>"
    email = EmailReplyParser::Email.new
    assert_equal "Bob Jones", email.send(:parse_name_from_address, address)
  end

  def test_parsing_name_from_address_with_no_name
    address = "bob@gmail.com"
    email = EmailReplyParser::Email.new
    assert_equal "", email.send(:parse_name_from_address, address)
  end

  def test_parsing_email_from_address_with_name
    address = "\"Bob Jones\" <bob@gmail.com>"
    email = EmailReplyParser::Email.new
    assert_equal "bob@gmail.com", email.send(:parse_email_from_address, address)
  end

  def test_parsing_email_from_address_without_name
    address = "bob@gmail.com"
    email = EmailReplyParser::Email.new
    assert_equal "bob@gmail.com", email.send(:parse_email_from_address, address)
  end

  def test_one_is_not_on
    reply = email("email_one_is_not_on")
    assert_match /One outstanding question/, reply.fragments[0].to_s
    assert_match /^On Oct 1, 2012/, reply.fragments[1].to_s
  end

  def test_new_content
    body = read("email_1_2")
    correct = read(File.join("new_content", "email_1_2"))
    assert_equal correct, EmailReplyParser.read(body).new_content
  end

  def read(name)
    IO.read EMAIL_FIXTURE_PATH.join("#{name}.txt").to_s
  end

  def test_normalize_name_first_last
    email = EmailReplyParser::Email.new
    name = "John Smith"
    assert_equal name, email.send(:normalize_name, name)
  end

  def test_normalize_name_last_first
    email = EmailReplyParser::Email.new
    name = "Smith, John"
    assert_equal "John Smith", email.send(:normalize_name, name)
  end

  def test_normalize_name_first_last_and_qualification
    email = EmailReplyParser::Email.new
    name = "John Smith, MD"
    assert_equal "John Smith", email.send(:normalize_name, name)
  end

  def test_parse_nil_body
    body = nil
    assert_equal "", EmailReplyParser.parse_reply(body)
  end

  def test_parse_empty_body
    body = ""
    assert_equal "", EmailReplyParser.parse_reply(body)
  end

  private

    def email(name)
      body = IO.read EMAIL_FIXTURE_PATH.join("#{name}.txt").to_s
      EmailReplyParser.read(body)
    end

    def visible_text(name)
      email(name).visible_text
    end

end
