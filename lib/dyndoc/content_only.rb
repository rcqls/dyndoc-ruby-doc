module Dyndoc

  class TemplateContentOnly 

    @@cfg={
      :version=>:V3,
      :format_doc => :tex, #instead of :output
      :format_output => :tex, ## :tex or :html or :tm or :odt
      :mode_doc => :tex, #execution mode
      :rootDoc=>"",
      #:model_doc=>"default", #NO MODEL in this mode
      :pre_doc=>[],
      :post_doc=>[],
      :cmd=> [], # :save , :cat, :pdf or :png, :view behaving differently depending on the format_doc
      :cmd_pandoc_options => [],
      :enc => "utf8"
    }


    attr_accessor :cfg, :tmpl_cfg, :content

    def initialize(cfg={})
      @content=""
      @cfg=cfg
      @tmpl_cfg=@@cfg.dup
      @tmplMngr=Dyndoc.tmpl_mngr
    end

    def init_tmpl
      @tmplMngr.init_doc(@tmpl_cfg)
      @tmplMngr.init_model(@content) #no model since @cfg[:model_doc] is nil! But, default libraries are loaded!    
      @tmplMngr.parse(File.read(Dyndoc.doc_filename("Dyn/Minimum"))+"\n",@tmplMngr.filterGlobal)
    end

    alias init_doc init_tmpl

    def require_dyndoc_libs(libs)
      libs="{#require]\n"+libs.split("\n").map{|lib| lib.split(",")}.flatten.uniq.join("\n")+"\n[#}\n"
      @tmplMngr.parse(libs,@tmplMngr.filterGlobal)
    end

    def prepare_content
      #Dyndoc.warn "prepare_content",@content
      out=@tmplMngr.parse(@content)
      return out
    end

    def make_content(content=nil)
      @content=content if content
      ##@tmplMngr.cfg[:debug]=true
      if @tmplMngr.cfg[:debug]
        ##puts "@content";p @content
        return prepare_content
      else
        begin
          return prepare_content 
        # rescue
        #   print "WARNING: fail to eval content #{@content} !!\n"
        #   return ""
        end
      end
    end

  end

end