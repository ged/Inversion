#!/usr/bin/env rspec -cfd -b
# vim: set noet nosta sw=4 ts=4 :

BEGIN {
	require 'pathname'
	basedir = Pathname( __FILE__ ).dirname.parent.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'spec/lib/helpers'
require 'inversion/template/calltag'

describe Inversion::Template::CallTag do

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	it "supports simple <identifier>.<methodname> syntax" do
		tag = Inversion::Template::CallTag.new( 'foo.bar' )

		tag.attribute.should == :foo
		tag.methodchain.should == '.bar'
	end

	it "supports index operator (<identifier>.methodname[ <arguments> ]) syntax" do
		tag = Inversion::Template::CallTag.new( 'foo.bar[8]' )

		tag.attribute.should == :foo
		tag.methodchain.should == '.bar[8]'
	end

	it "supports index operator (<identifier>[ <arguments> ]) syntax" do
		tag = Inversion::Template::CallTag.new( 'foo[8]' )

		tag.attribute.should == :foo
		tag.methodchain.should == '[8]'
	end

	it "supports <identifier>.<methodname>( <arguments> ) syntax" do
		tag = Inversion::Template::CallTag.new( 'foo.bar( 8, :baz )' )

		tag.attribute.should == :foo
		tag.methodchain.should == '.bar( 8, :baz )'
	end

	it "fails to parse if it doesn't have a methodchain" do
		expect {
			Inversion::Template::CallTag.new( 'foo' )
		}.to raise_exception( Inversion::ParseError, /expected one of/i )
	end


	describe "renders as the results of calling the tag's method chain on a template attribute" do

		before( :each ) do
			@attribute_object = mock( "template attribute" )
		end

		it "renders a single method call with no arguments" do
			template = Inversion::Template.new( 'this is <?call foo.bar ?>' )
			template.foo = @attribute_object
			@attribute_object.should_receive( :bar ).with( no_args() ).and_return( "the result" )

			template.render.should == "this is the result"
		end

		it "renders a single method call with one argument" do
			template = Inversion::Template.new( 'this is <?call foo.bar(8) ?>' )
			template.foo = @attribute_object
			@attribute_object.should_receive( :bar ).with( 8 ).and_return( "the result" )

			template.render.should == "this is the result"
		end

		it "renders a call with a single index operator" do
			template = Inversion::Template.new( 'lines end with <?call config[:line_ending] ?>' )
			template.config = { :line_ending => 'newline' }

			template.render.should == "lines end with newline"
		end

		it "renders a single method call with multiple arguments" do
			template = Inversion::Template.new( 'this is <?call foo.bar(8, :woo) ?>' )
			template.foo = @attribute_object
			@attribute_object.should_receive( :bar ).with( 8, :woo ).and_return( "the result" )

			template.render.should == "this is the result"
		end

		it "renders multiple method calls with no arguments" do
			additional_object = mock( 'additional template attribute' )
			template = Inversion::Template.new( 'this is <?call foo.bar.baz ?>' )
			template.foo = @attribute_object
			template.foo.should_receive( :bar ).and_return( additional_object )
			additional_object.should_receive( :baz ).with( no_args() ).and_return( "the result" )

			template.render.should == "this is the result"
		end

		it "renders multiple method calls with arguments" do
			additional_object = mock( 'additional template attribute' )
			template = Inversion::Template.new( 'this is <?call foo.bar( 8 ).baz( :woo ) ?>' )
			template.foo = @attribute_object
			template.foo.should_receive( :bar ).with( 8 ).and_return( additional_object )
			additional_object.should_receive( :baz ).with( :woo ).and_return( "the result" )

			template.render.should == "this is the result"
		end
	end


	it "can render itself as a comment for template debugging" do
		tag = Inversion::Template::CallTag.new( 'foo.bar( 8, :baz )' )
		tag.as_comment_body.should == "Call: { template.attributes[ :foo ].bar( 8, :baz ) }"
	end

end
