#!/usr/bin/env rspec -cfd -b
# vim: set noet nosta sw=4 ts=4 :

BEGIN {
	require 'pathname'
	basedir = Pathname( __FILE__ ).dirname.parent.parent.parent
	libdir  = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s )  unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'spec/lib/helpers'
require 'inversion/template/parser'

describe Inversion::Template::Parser do

	before( :all ) do
		setup_logging( :fatal )
		Inversion::Template::Tag.load_all
	end

	before( :each ) do
		@template = double( "An Inversion::Template" )
	end

	it "parses a string with no PIs as a single text node" do
		result = Inversion::Template::Parser.new( @template ).parse( "render unto Caesar" )

		result.should have( 1 ).member
		result.first.should be_a( Inversion::Template::TextNode )
		result.first.body.should == 'render unto Caesar'
	end

	it "parses an empty string as a empty tree" do
		result = Inversion::Template::Parser.new( @template ).parse( "" )
		result.should be_empty
	end

	it "parses a string with a single 'attr' tag as a single AttrTag node" do
		result = Inversion::Template::Parser.new( @template ).parse( "<?attr foo ?>" )

		result.should have( 1 ).member
		result.first.should be_a( Inversion::Template::AttrTag )
		result.first.body.should == 'foo'
	end

	it "parses a single 'attr' tag surrounded by plain text" do
		result = Inversion::Template::Parser.new( @template ).parse( "beginning<?attr foo ?>end" )

		result.should have( 3 ).members
		result[0].should be_a( Inversion::Template::TextNode )
		result[1].should be_a( Inversion::Template::AttrTag )
		result[1].body.should == 'foo'
		result[2].should be_a( Inversion::Template::TextNode )
	end

	it "ignores unknown tags by default" do
		result = Inversion::Template::Parser.new( @template ).parse( "Text <?hoooowhat ?>" )

		result.should have( 2 ).members
		result[0].should be_a( Inversion::Template::TextNode )
		result[1].should be_a( Inversion::Template::TextNode )
		result[1].body.should == '<?hoooowhat ?>'
	end

	it "can raise exceptions on unknown tags" do
		expect {
			Inversion::Template::Parser.new( @template, :ignore_unknown_tags => false ).
				parse( "Text <?hoooowhat ?>" )
		}.to raise_exception( Inversion::ParseError, /unknown tag/i )
	end

	it "can raise exceptions on unclosed (nested) tags" do
		expect {
			Inversion::Template::Parser.new( @template ).parse( "Text <?attr something <?attr something_else ?>" )
		}.to raise_exception( Inversion::ParseError, /unclosed tag/i )
	end

	it "can raise exceptions on unclosed (eof) tags" do
		expect {
			Inversion::Template::Parser.new( @template ).parse( "Text <?hoooowhat" )
		}.to raise_exception( Inversion::ParseError, /unclosed tag/i )
	end


	describe Inversion::Template::Parser::State do

		before( :each ) do
			@state = Inversion::Template::Parser::State.new( @template )
		end

		it "returns the node tree if it's well-formed" do
			open_tag = Inversion::Template::ForTag.new( 'foo in bar' )
			@state << open_tag
			@state << Inversion::Template::EndTag.new( 'for' )

			@state.tree.should == [ open_tag ]
		end

		it "knows it is well-formed if there are no open tags" do
			@state << Inversion::Template::ForTag.new( 'foo in bar' )
			@state.should_not be_well_formed

			@state << Inversion::Template::ForTag.new( 'foo in bar' )
			@state.should_not be_well_formed

			@state << Inversion::Template::EndTag.new( 'for' )
			@state.should_not be_well_formed

			@state << Inversion::Template::EndTag.new( 'for' )
			@state.should be_well_formed
		end

		it "raises an error on the addition of a unbalanced end tag" do
			expect {
				@state << Inversion::Template::EndTag.new( 'for' )
			}.to raise_exception( Inversion::ParseError, /unbalanced/i )
		end

		it "raises an error on the addition of a mismatched end tag" do
			@state << Inversion::Template::ForTag.new( 'foo in bar' )

			expect {
				@state << Inversion::Template::EndTag.new( 'if' )
			}.to raise_exception( Inversion::ParseError, /unbalanced/i )
		end

		it "raises an error when the tree is fetched if it isn't well-formed" do
			open_tag = Inversion::Template::ForTag.new( 'foo in bar' )
			@state << open_tag

			expect {
				@state.tree
			}.to raise_exception( Inversion::ParseError, /unclosed/i )
		end

		it "calls the #before_append callback on nodes that are appended to it" do
			node = mock( "node", :is_container? => false, :after_append => nil )
			node.should_receive( :before_append ).with( @state )

			@state << node
		end

		it "calls the #after_append callback on nodes that are appended to it" do
			node = mock( "node", :is_container? => false, :before_append => nil )
			node.should_receive( :after_append ).with( @state )

			@state << node
		end


	end

end

