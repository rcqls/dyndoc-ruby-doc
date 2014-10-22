require 'dyndoc/software'
require 'dyndoc-core'

module Dyndoc

  module DynConfig

    def init_cfg(cfg=nil)
      @cfg=@@cfg.dup
      read_cfg(cfg) if cfg
    end

    def read_cfg(cfg)
      cfg.each_key do |k|
        @cfg[k]=cfg[k]
      end
    end

    # append with partial match
    def append_cfg(cfg)
      return unless cfg.respond_to? "[]"
      keys=@cfg.keys.map{|e| e.to_s}.sort
      cfg.each_key do |k|
        #like R, partial match of the parameter names
        if k2=keys.find{|e| e=~/^#{k}/}
          @cfg[k2.to_sym]=cfg[k]
        end
      end
    end

    def [](key)
      @cfg[key]
    end

    def []=(key,value)
     @cfg[key]=value
     return self
    end

  end

  EMPTY_ODT=File.join(ENV["HOME"],"dyndoc","share","odt","2004","empty.odt") if File.exists? File.join(ENV["HOME"],"dyndoc","share","odt","2004","empty.odt")
  EMPTY_ODT=File.join($dyn_gem_root,"share","odt","2004","emptyTex4Ht.odt") if $dyn_gem_root and File.exists? File.join($dyn_gem_root,"share","odt","2004","empty.odt")
  EMPTY_ODT=File.join("/export/prjCqls","share","rsrc","dyndoc","odt","2004","empty.odt") if  File.exists? File.join("/export/prjCqls","share","rsrc","dyndoc","odt","2004","empty.odt")

  #just for a shortcut
  TexDoc={
    :docs=>{
      "main"=>{:cmd=>[:save,:pdf,:view]},
    }
  }

  OdtDoc={
    :docs=>{
      "main"=>{:cmd=>[:save],:format_doc=>:odt},
    }
  }

  TtmDoc={
    :docs=>{
      "main"=>{:cmd=>[:save],:format_doc=>:ttm},
    }
  }

  class TemplateDocument

    # GOAL: to deal with a master document which may generate many output with different formats
    # RMK: no attempt to deal with template in odt format which is a next objective.
    # RMK2: later on, one could imagine to propose a text language easily convertible to the expected formats

    @@cfg={
      :working_dir => "", #directory where dyndoc is processed
      :dyndoc_mode => :normal, #default mode, alternative modes :local_server, :remote_server
      :filename_tmpl=>"", #be specified later
      :filename_tmpl_orig=>"", #be specified later
      :dirname_docs=>"", #default directory unless specified by doc! 
      :rootDoc=>"",
      :user_input=>[],
      :tag_tmpl=>[], #old part_tag!
      :keys_tmpl=>[],
      :docs=>[], #this one is introduced from version V3 to deal with multidocuments 
      :doc_list=>[], #list of documents if nonempty
      :cmd=>[], #list of commands if nonempty for every document
      :cmd_pandoc_options => [], #pandoc options
      :dtag=>:dtag,
      :dtags=>[:dtag],
      :raw_mode=>false,
      :model_tmpl=>"default",
      :model_doc=>"default",
      :append => "",
      :verbose => false,
      :debug => false
    }


    include DynConfig

    attr_accessor :tmpl_mngr, :docs, :cfg, :basename, :basename_orig, :content

    def initialize(name) #docs is a hash containing all the files
      @name=name
      ## read config from name
      @cfg=@@cfg.dup
      read_cfg(@name)
      ## the template manager
      @tmpl_mngr = Dyndoc::Ruby::TemplateManager.new(@cfg)
      ## the documents
      @docs={}
      make_doc_list
      if @cfg[:content] #a non file based document is a Hash cfg with :content inside (give a basename used for generated files) 
        @content=@cfg[:content]
      else
        # find the basename of the template
        @basename=basename_tmpl
        @dirname=File.dirname(@basename)
        @basename=File.basename(@basename)
  #p @basename
        @basename_orig=basename_tmpl_orig
        @dirname_orig=File.dirname(@basename_orig)
        @basename_orig=File.basename(@basename_orig)
  #p @basename_orig
        # read content of the template
        @content=File.read(@cfg[:filename_tmpl])
      end
      # list of Document objects
#puts "@doc_list (init)";p @doc_list
      @doc_list.each do |kdoc|
        @docs[kdoc]=Document.new(kdoc,self)
      end
    end

    def read_cfg(name,mode=:all)
      # cfg_dyn is the options given inside the master template
      cfg_dyn=nil
      
       
      name_tmpl=Dyndoc.name_tmpl(name,mode)
#Dyndoc.warn "read_cfg:name_tmpl",[name,name_tmpl]
      if name_tmpl
        name_tmpl2=Dyndoc.directory_tmpl? name_tmpl
        if name_tmpl2
          cfg_dyn=cfg_dyn_from(name_tmpl2)
          cfg_dyn[:filename_tmpl]=name_tmpl2
        else
          cfg_dyn=Dyndoc::TexDoc
        end
        cfg_dyn[:filename_tmpl_orig] = name_tmpl
      end
#Dyndoc.warn "read_cfg:cfg_dyn",cfg_dyn

      #otherwise it is the default version!
      append_cfg(cfg_dyn) if cfg_dyn
      #read the optional cfg
      #p [:cfg_dyn_readCurDyn,Dyndoc.cfg_dyn[:doc_list]]
      
    end

    def cfg_dyn_from(tmpl)
      code,cfg_file=nil,nil
      code=File.read(cfg_file) if (cfg_file=(Dyndoc::Utils.cfg_file_exists? tmpl))
      ##puts "code";p code;p cfg_file
      Utils.clean_bom_utf8!(code) if code
      code="Dyndoc::TexDoc" unless code
      if code and code.is_a? String
          code="{\n"+code+"\n}" if code=~/\A\s*\:/m #to avoid at the beginning { and at the end }!
          p [code,Object.class_eval(code)]
          return Object.class_eval(code)
      end
      return nil
    end

    def make_doc_list
      doc_list=@cfg[:docs].keys
#puts "@cfg[doc_list]";p @cfg[:doc_list]
      doc_list &= @cfg[:doc_list] unless @cfg[:doc_list].empty?
#p doc_list
      #deal with aliases
      doc_alias={}
      @cfg[:docs].each_pair{|key,doc|
      	doc_alias[key]=doc if doc.is_a? Array
      }
#puts "doc_alias";p doc_alias
      doc_list=doc_list.map{|key| (doc_alias[key] ?  doc_alias[key] : key )}.flatten until (doc_list &  doc_alias.keys).empty?
      @doc_list=doc_list
#puts "doc_list";p @doc_list
    end

    # document basename from template filename
    def basename_tmpl
      mode=Dyndoc.guess_mode(@cfg[:filename_tmpl])
      ##puts "mode";p mode;p Dyndoc.tmplExt[mode]
      if mode
        name,ext=@cfg[:filename_tmpl].scan(/^(.*)(?:#{Dyndoc.tmplExt[mode].join("|")})$/).flatten.compact
      else
        name,ext=@cfg[:filename_tmpl].scan(/^(.*)(?:_tmpl(\..*)|(\.dyn))$/).flatten.compact
      end
      #p name
      name
    end

    def basename_tmpl_orig
      mode=Dyndoc.guess_mode(@cfg[:filename_tmpl_orig])
      if mode
        name,ext=@cfg[:filename_tmpl_orig].scan(/^(.*)(?:#{Dyndoc.tmplExt[mode].join("|")})$/).flatten.compact
      else
        name,ext=@cfg[:filename_tmpl_orig].scan(/^(.*)(?:_tmpl(\..*)|(\.dyn))$/).flatten.compact
      end
      name
    end

    def make_all
#puts "@doc_list"; p @doc_list
      @doc_list.each do |kdoc|
	      @docs[kdoc].make_all
      end
    end

  end

  class Document ## or more explicitly, CreatedDocument from TemplateDocument
    # each document has its own config parameters

    @@cfg={
      :key_doc=>"", #to specify in initialize
      :format_doc => :tex, #instead of :output
      :format_output => :tex,
      :mode_doc => :tex, #execution mode
      :rootDoc=>"",
      :model_doc=>"default",
      :pre_doc=>[],
      :post_doc=>[],
      :cmd=> [], # :save , :cat, :pdf or :png, :view behaving differently depending on the format_doc
      :cmd_pandoc_options => [],
      :filename_doc => "",
      :created_docs => [], 
      :dirname_doc=>"",
      :append_doc=>"",
      :tag_doc => [],
      :keys_doc=>[],
      :enc => "utf8",
      :options => {}, # added for example to compile twice latex
      :input => [] # added
    }

    def Document.cfg
      @@cfg.dup
    end

    include Dyndoc::DynConfig

    # gather in @cfg optionnal parameters 
    # @content really matters to be included in @cfg!

    attr_accessor :tmpl_doc, :cfg, :content, :inputs

    def initialize(key_doc,tmpl_doc)
      @tmpl_doc=tmpl_doc #to be aware of the cfg of tmpl_doc!
      @cfg=Document.cfg
      @content=""
      @cfg[:key_doc]=key_doc #just to record the key of this document
      # update @cfg
      ## cmd
      @cfg[:cmd].uniq!
      @cfg[:cmd] = [:save] if @cfg[:model_doc] and @cfg[:model_doc] != "default"
      append_cfg(@tmpl_doc.cfg[:docs][key_doc])
      # update cmd
      #p @tmpl_doc.cfg[:cmd];p @cfg[:cmd]
      @cfg[:cmd]=@tmpl_doc.cfg[:cmd] unless @tmpl_doc.cfg[:cmd].empty?
      ## TODO: MODE MULTIDOC => maybe to correct if options differ for each document
      @cfg[:cmd_pandoc_options]=@tmpl_doc.cfg[:cmd_pandoc_options] unless @tmpl_doc.cfg[:cmd_pandoc_options].empty?
      # debug mode
      p @tmpl_doc.cfg if @tmpl_doc.cfg[:debug]
      p @cfg if @tmpl_doc.cfg[:debug]
      # autocomplete the document filename if necessary!
      filename_completion if @cfg[:filename_doc].empty?
    end

=begin
    # do we have to save the content to some file
    def to_be_saved? 
      @cfg[:filename_doc]!=:no
    end
=end
    
    def filename_completion
#p @tmpl_doc.basename_orig
#p @cfg[:append_doc]
#p Dyndoc.docExt(@cfg[:format_doc])
      @cfg[:filename_doc]=@tmpl_doc.basename_orig+@tmpl_doc.cfg[:append]+@cfg[:append_doc]+Dyndoc.docExt(@cfg[:format_doc])
    end

# start ##################################################
    def make_all
      make_prelim
      cd_new
      open_log
      make_content
      @content=make_ttm if @cfg[:format_doc]==:ttm
#puts "make_all";p @cfg[:cmd]
      make_save if @cfg[:cmd].include? :save
      make_pandoc if @cfg[:cmd].include? :pandoc
      make_backup if @cfg[:cmd].include? :backup
      make_cat if @cfg[:cmd].include? :cat
      make_pdf if @cfg[:cmd].include? :pdf
      make_png if @cfg[:cmd].include? :png
      make_view if @cfg[:cmd].include? :view
      close_log
      cd_old
    end

    def open_log
      #p [@tmpl_doc.basename_orig,@tmpl_doc.basename]
      logfile=File.join(@dirname,@tmpl_doc.basename_orig+".dyn_log")
      #p logfile
      $dyn_logger=File.new(logfile,"w")
      @cfg[:created_docs] << @basename+".dyn_log"
    end

    def close_log
      $dyn_logger.close
    end

    def make_prelim
      init_doc
      @cfg[:created_docs]=[]
      @dirname,@filename=File.split(File.expand_path @cfg[:filename_doc])
      #update @dirname if @cfg[:dirname_doc] or @tmpl_doc.cfg[:dirname_docs] is fixed!
      if @dirname.empty? and @cfg[:dirname_doc] and !@cfg[:dirname_doc].empty? and File.exist? @cfg[:dirname_doc]
	      @dirname= @cfg[:dirname_doc]
      elsif @dirname.empty? and @tmpl_doc.cfg[:dirname_docs] and !@tmpl_doc.cfg[:dirname_docs].empty? and File.exist? @tmpl_doc.cfg[:dirname_docs]
	      @dirname= @tmpl_doc.cfg[:dirname_docs]
      end
      #rsrc!
      $dyn_rsrc=File.join("rsrc",@filename)
      @basename=File.basename(@filename,".*")
      Dyndoc.cfg_dir[:file]=File.expand_path(@dirname)
      @curdir=Dir.pwd
=begin
      # read current path if it exists
      cur_path=File.join(@dirname,".dyn_path")
      Dyndoc.setRootDoc(@cfg[:rootDoc],File.read(cur_path).chomp,true) if File.exists? cur_path
      Dyndoc.make_append unless Dyndoc.appendVar
=end
    #p "ici";p @cfg
      require "dyndoc/common/init"
      #p PANDOC_CMDS
      if @basename =~ /\_(md|tex)2(odt|docx|beamer|s5|dzslides|slideous|slidy)$/ or (pandoc_cmd=PANDOC_CMDS.include? @cfg[:cmd_pandoc_options][0])
        #p [@basename,$1,$2,pandoc_cmd]
        if pandoc_cmd
          @cfg[:cmd_pandoc_options][0] =~ /(md|tex)2(odt|docx|beamer|s5|dzslides|slideous|slidy)$/
        else
          @basename = @basename[0..(@basename.length-$1.length-$2.length-3)] unless pandoc_cmd
        end
        #p @basename
        @cfg[:cmd] << :pandoc
        @cfg[:format_doc]=@cfg[:mode_doc]=$1.to_sym
        @cfg[:format_output]=$2.to_sym
         
        if @cfg[:cmd_pandoc_options].empty? or pandoc_cmd
          #p [@cfg[:format_doc].to_s , @cfg[:format_output].to_s]
          case @cfg[:format_doc].to_s + "2" + @cfg[:format_output].to_s
          when "md2odt"
            @cfg[:cmd] = [:pandoc]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".odt"
          when "md2docx"
            @cfg[:cmd] = [:pandoc]
            @cfg[:model_doc]=nil
            @cfg[:cmd_pandoc_options]=["-s","-S"]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".docx"
          when "tex2docx"
            @cfg[:cmd] = [:save,:pandoc]
            @cfg[:pandoc_file_input]=@filename
            @cfg[:model_doc]=nil
            @cfg[:cmd_pandoc_options]=["-s"]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".docx"
          when "md2beamer"
            @cfg[:cmd] = [:pandoc]
            @cfg[:cmd_pandoc_options]=["-t","beamer"]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".pdf"
          when "md2dzslides"
            @cfg[:cmd] = [:pandoc]
            @cfg[:cmd_pandoc_options]=["-s","--mathml","-i","-t","dzslides"]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".html"
          when "md2slidy"
            @cfg[:cmd] = [:pandoc]
            @cfg[:cmd_pandoc_options]=["-s","--webtex","-i","-t","slidy"]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".html"  
          when "md2s5"
            @cfg[:cmd] = [:pandoc]
            @cfg[:cmd_pandoc_options]=["-s","--self-contained","--webtex","-i","-t","s5"]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".html"
          when "md2slideous"
            @cfg[:cmd] = [:pandoc]
            @cfg[:cmd_pandoc_options]=["-s","--mathjax","-i","-t","slideous"]
            @cfg[:pandoc_file_output]=@basename+@cfg[:append_doc]+".html"
          end
        end
      end
    end

    def init_doc 
      Dyndoc.mode=out=@cfg[:format_doc]
      unless @tmpl_doc.cfg[:raw_mode]
        if ( tmp=Dyndoc.doc_filename("Dyn/.preload",[""],nil))
          @cfg[:pre_doc] += File.read(tmp).split("\n").map{|l| l.split(",")}.flatten.map{|e| e.strip}
        end
    
        if (tmp=Dyndoc.doc_filename("Dyn/.postload",[""],nil))
          @cfg[:post_doc] += File.read(tmp).split("\n").map{|l| l.split(",")}.flatten.map{|e| e.strip}
        end
        if out
## default preload
	        out=:tex if out==:ttm
          outDir=out.to_s.capitalize
          if (tmp=Dyndoc.doc_filename("#{outDir}/.preload",[""],nil))
            @cfg[:pre_doc] += File.read(tmp).split("\n").map{|l| l.split(",")}.flatten.map{|e| e.strip}.map{|t| File.join(Dyndoc.cfg_dir[:tmpl_path][out],t)}
          end
## default postload
          if (tmp=Dyndoc.doc_filename("#{outDir}/.postload",[""],nil))
            @cfg[:post_doc] += File.read(tmp).split("\n").map{|l| l.split(",")}.flatten.map{|e| e.strip}.map{|t| File.join(Dyndoc.cfg_dir[:tmpl_path][out],t)}
          end
        end
      end
#p @cfg[:pre_doc]
#p @cfg[:post_doc]
      #model_doc
      @cfg[:model_doc]=nil unless @tmpl_doc.cfg[:model_tmpl]
      @cfg[:model_doc]=@tmpl_doc.cfg[:model_doc] if @tmpl_doc.cfg[:model_doc]
      @cfg[:cmd] -= [:png,:pdf,:view] if @cfg[:model_doc]=="content"
      # TO REMOVE: Dyndoc.mode=(out)
      # prepare the initialization of the TemplateManager
      @tmpl_doc.tmpl_mngr.init_doc(@cfg)
    end 

    def cd_new
      Dir.chdir(@dirname)
    end

    def cd_old
      Dir.chdir(@curdir)
    end

#like txt (see below) but for string!
    def output(input,echo=0)
      @cfg[:cmd]=:txt
      @cfg[:output]=:txt if @cfg[:output]== :tex
      @cfg[:raw_mode],@cfg[:model_tmpl]=false,nil
      init(@cfg[:output])
      @tmpl_doc.echo=echo
      @tmpl_doc.reinit 
      @tmpl_doc.output input
    end


# make ###########################################
# make content
   def make_content
      if true #@tmpl_doc.cfg[:debug]
        @tmpl_doc.tmpl_mngr.echo=0
        @tmpl_doc.tmpl_mngr.doc=self
        @content=@tmpl_doc.tmpl_mngr.output(@tmpl_doc.content)
        print "\nmake content for #{@basename} in #{@dirname} -> ok\n"
      else
        print "\nmake content for #{@basename} in #{@dirname}\n"
        begin
          @tmpl_doc.tmpl_mngr.echo=0
          @tmpl_doc.tmpl_mngr.doc=self
          @content=@tmpl_doc.tmpl_mngr.output(@tmpl_doc.content)
          ##puts "@content";p @content
          print " -> ok\n"
        rescue
          ok=false
          print " -> NO, NO and NO!!\n"
        end
      end
    end

    def make_odt_content_xml
      @content_xml=REXML::Document.new(@content)
#p @content_xml.to_s
    end

    def make_odt_automatic_styles
#puts "make_odt_automatic_styles:@inputs"; p @inputs
      return if !@inputs or @inputs.empty?
      autostyles = @content_xml.root.elements['office:automatic-styles']
#puts "autostyles";p autostyles
#p @automatic_styles
      # add the automatic styles from input template 
      if autostyles 
        @inputs.values.each do |input|
          input.automatic_styles.each_element do |e|
            autostyles << e
          end
        end
      end
    end

    def make_odt_ressources 
      return if !@inputs or @inputs.empty?
      # create directories if necessary
      @ar.find_entry('ObjectReplacements') || @ar.mkdir('ObjectReplacements')
      @ar.find_entry('Pictures') || @ar.mkdir('Pictures')
      # create the necessary files
      @inputs.values.each do |input|
	    input.xlink_href.keys.each do |key|
	        if (entry=input.ar.find_entry(key))
	        @ar.get_output_stream(input.xlink_href[key]) do |f|
	        f.write input.ar.read(entry)
	    end
	  end
	end
      end
    end

    def make_pandoc
      opts=@cfg[:cmd_pandoc_options]+["-o",@cfg[:pandoc_file_output]]
      puts "make_pandoc";p @content
      if @cfg[:pandoc_file_input]
        opts << @cfg[:pandoc_file_input]
        Converter.pandoc(nil,opts.join(" "))
      else
        Converter.pandoc(@content,opts.join(" "))
      end
      @cfg[:created_docs] << @cfg[:pandoc_file_output]
    end

    def make_save
	    case @cfg[:format_doc]
	    when :odt
	      #before saving: make automatic styles!
	      make_odt_content_xml
	      make_odt_automatic_styles
	      FileUtils.cp(EMPTY_ODT,@cfg[:filename_doc]) unless File.exists? @cfg[:filename_doc]
        require  'zip'
        @ar=Zip::ZipFile.open(@cfg[:filename_doc])
        @ar.get_output_stream('content.xml') do |f|
	        f.write @content_xml.to_s
	      end

	      make_odt_ressources
	      @ar.close
	    else
	      print "\nsave content in #{@cfg[:filename_doc]} or #{@filename}"
	      File.open(@cfg[:filename_doc],"w") do |f|
	        f << @content
	      end
	      print " -> ok\n"
	      @cfg[:created_docs] << @filename #( @dirname.empty? ? "" : @dirname+"/" ) + @filename
	    end
    end
 
    def make_cat
      puts @content
    end


# make pdf

    def make_pdf
      nb=1
      nb = @cfg[:options][:pdflatex] if @cfg[:options][:pdflatex]
      nb.times { make_pdflatex } if @cfg[:format_doc]==:tex
    end

# make prj-tex
    def make_prj_tex
      system "prj-tex #{@basename}"
      print "\nprj-tex #{@basename} in #{@dirname} -> ok\n"
    end

# make pdflatex
    def make_pdflatex
      if File.read(@basename+".tex").empty?
        msg="No pdflatex #{@basename} in #{@dirname} since empty file!"
        print "\n==> "+msg
        $dyn_logger.write("ERROR pdflatex: "+msg+"\n") unless Dyndoc.cfg_dyn[:dyndoc_mode]==:normal
        return ""
      end
      print "\n==> #{Dyndoc.pdflatex} #{@basename} in #{@dirname}"
      # NEW: Not to be devkit dependent!!! 
      # if RUBY_PLATFORM =~ /(win|w)32$/
      #   unless SOFTWARE[:taskkill]
      #       cmd = `which taskkill`.strip
      #       SOFTWARE[:taskkill]=cmd unless cmd.empty?
      #   end
      #   if SOFTWARE[:taskkill]
      #     system(SOFTWARE[:taskkill]+" /FI \"windowtitle eq "+@basename+".pdf*\"")
      #   end
      # end
      out=`#{Dyndoc.pdflatex} -halt-on-error -file-line-error -interaction=nonstopmode #{@basename}`
      out=out.b if RUBY_VERSION >= "1.9" #because out is not necessarily utf8 encoded  
      out=out.split("\n")
      if out[-2].include? "Fatal error"
        if Dyndoc.cfg_dyn[:dyndoc_mode]==:normal
          print " -> NOT OKAY!!!\n==> "
          puts out[-4...-1]
          raise SystemExit 
        else
          # File.open("#{@dirname}/#{@basename}.dyn_log","w") do |f|
          #   f << out[-4...-1]
          # end
          #p out[-4...-1]
          $dyn_logger.write("ERROR pdflatex: "+out[-4...-1].to_s+"\n")
          @cfg[:created_docs] << @basename+".log"
        end
      else 
        print " -> OKAY!!!\n"
        @cfg[:created_docs] << @basename+".pdf" #( @dirname.empty? ? "" : @dirname+"/" ) + @basename+".pdf"
      end
    end

# make png

    def make_png
      make_dvipng if @cfg[:format_doc]==:tex
    end

# make latex and dvipng 
    def make_dvipng
        system "latex #{@basename}.tex"
        print "\nlatex #{@basename}.tex -> ok\n"
        system "dvipng --nogssafer #{@basename}.dvi -o #{@basename}.png"
        print "\ndvipng --nogssafer #{@basename}.dvi -o #{@basename}.png -> ok\n"
    end

# make ttm
    def make_ttm
#puts "make_ttm:begin"
      Dyndoc::Converter.ttm(@content)
    end


# make view
    def make_view
      make_viewpdf if @cfg[:cmd].include? :pdf 
      make_viewpng if @cfg[:cmd].include? :png 
    end


# make view pdf
    def make_viewpdf
      if RUBY_PLATFORM =~ /(win|w)32$/
        unless SOFTWARE[:pdfviewer]
            SOFTWARE[:pdfviewer]="start"
        end
      elsif RUBY_PLATFORM =~ /darwin/
        unless SOFTWARE[:pdfviewer]
            SOFTWARE[:pdfviewer]="open"
        end
      else
        if @tmpl_doc.cfg[:pdfviewer]=="xpdf"
          SOFTWARE[:pdfviewer]="xpdf"
        else
          cmd = `which #{@tmpl_doc.cfg[:pdfviewer]}`.strip
          SOFTWARE[:pdfviewer]=cmd unless cmd.empty?
        end
      end   
      if SOFTWARE[:pdfviewer]
        if SOFTWARE[:pdfviewer]=="xpdf"
  ##test xpdf is  already open
          if `ps aux`.scan("xpdf-#{@basename}").length>0
            system "xpdf -remote xpdf-#{@basename} -reload"
          else
            system "xpdf -remote xpdf-#{@basename}  #{@basename}.pdf&"
          end
          print "\n==> xpdf #{@cfg[:filename_doc]}.pdf -> OKAY!!!\n"
        else
          if RUBY_PLATFORM =~ /(win|w)32$/
            `start /B #{@basename}.pdf`
          elsif RUBY_PLATFORM =~ /darwin/
            `open #{@basename}.pdf`
          else
            `#{SOFTWARE[:pdfviewer]} #{@basename}.pdf&`
          end
        end
      end
    end

# make view png
    def make_viewpng
        system "#{@tmpl_doc.cfg[:pngviewer]} #{@basename}.png&"
    end
    
# TODO: TO UPDATE!!!! file ############################################
# file tex
    def tex(name)
      @name=name
      start
      cd_new
      make_tex
      make_backup
      cd_old
    end

# file pdf
    def tex_pdf(name)
      @cfg[:cmd]=:pdf
      @name=name
      start
      cd_new
      make_tex
      make_backup
      make_pdflatex
      cd_old
    end

# file pdf+viewer
    def tex_xpdf(name)
      tex_pdf(name)
      make_viewpdf
    end

# file png
    def tex_png(name)
      @cfg[:cmd]=:png
      @name=name
      start
      cd_new
      make_tex
      make_dvipng
      cd_old
      make_viewpng
    end

#file txt
    def txt(name)
      @cfg[:cmd]=:txt
      @cfg[:output]=:txt if @cfg[:output]== :tex
      @cfg[:raw_mode],@cfg[:model_tmpl]=false,nil
      @name=name
      start
      cd_new
      make_txt
      cd_old
    end

  end
end
