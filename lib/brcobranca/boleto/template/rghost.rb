# -*- encoding: utf-8 -*-

begin
  require 'rghost'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rghost'
  require 'rghost'
end

begin
  require 'rghost_barcode'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rghost_barcode'
  require 'rghost_barcode'
end

module Brcobranca
  module Boleto
    module Template
      # Templates para usar com Rghost
      module Rghost
        extend self
        include RGhost unless self.include?(RGhost)
        RGhost::Config::GS[:external_encoding] = Brcobranca.configuration.external_encoding
        RGhost::Config::GS[:default_params] << '-dNOSAFER'

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        def to(formato, options = {})
          modelo_generico(self, options.merge!(formato: formato))
        end

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        def lote(boletos, options = {})
          modelo_generico_multipage(boletos, options)
        end

        #  Cria o métodos dinâmicos (to_pdf, to_gif e etc) com todos os fomátos válidos.
        #
        # @return [Stream]
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        # @example
        #  @boleto.to_pdf #=> boleto gerado no formato pdf
        def method_missing(m, *args)
          method = m.to_s
          if method.start_with?('to_')
            modelo_generico(self, (args.first || {}).merge!(formato: method[3..-1]))
          else
            super
          end
        end

        private

        # Retorna um stream pronto para gravação em arquivo.
        #
        # @return [Stream]
        # @param [Boleto] Instância de uma classe de boleto.
        # @param [Hash] options Opção para a criação do boleto.
        # @option options [Symbol] :resolucao Resolução em pixels.
        # @option options [Symbol] :formato Formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        def modelo_generico(boleto, options = {})
          doc = Document.new paper: :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__), '..', '..', 'arquivos', 'templates', 'modelo_generico.eps')

          fail 'Não foi possível encontrar o template. Verifique o caminho' unless File.exist?(template_path)

          modelo_generico_template(doc, boleto, template_path)
          modelo_generico_cabecalho(doc, boleto)
          modelo_generico_rodape(doc, boleto)

          # Gerando codigo de barra com rghost_barcode
          doc.barcode_interleaved2of5(boleto.codigo_barras, width: '10.3 cm', height: '1.3 cm', x: '0.7 cm', y: '5.8 cm') if boleto.codigo_barras

          # Gerando stream
          formato = (options.delete(:formato) || Brcobranca.configuration.formato)
          resolucao = (options.delete(:resolucao) || Brcobranca.configuration.resolucao)
          doc.render_stream(formato.to_sym, resolution: resolucao)
        end

        # Retorna um stream para multiplos boletos pronto para gravação em arquivo.
        #
        # @return [Stream]
        # @param [Array] Instâncias de classes de boleto.
        # @param [Hash] options Opção para a criação do boleto.
        # @option options [Symbol] :resolucao Resolução em pixels.
        # @option options [Symbol] :formato Formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        def modelo_generico_multipage(boletos, options = {})
          doc = Document.new paper: :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__), '..', '..', 'arquivos', 'templates', 'modelo_generico.eps')

          fail 'Não foi possível encontrar o template. Verifique o caminho' unless File.exist?(template_path)

          boletos.each_with_index do |boleto, index|

            modelo_generico_template(doc, boleto, template_path)
            modelo_generico_cabecalho(doc, boleto)
            modelo_generico_rodape(doc, boleto)

            # Gerando codigo de barra com rghost_barcode
            doc.barcode_interleaved2of5(boleto.codigo_barras, width: '10.3 cm', height: '1.3 cm', x: '0.7 cm', y: '5.8 cm') if boleto.codigo_barras
            # Cria nova página se não for o último boleto
            doc.next_page unless index == boletos.length - 1

          end
          # Gerando stream
          formato = (options.delete(:formato) || Brcobranca.configuration.formato)
          resolucao = (options.delete(:resolucao) || Brcobranca.configuration.resolucao)
          doc.render_stream(formato.to_sym, resolution: resolucao)
        end

        # Define o template a ser usado no boleto
        def modelo_generico_template(doc, _boleto, template_path)
          doc.define_template(:template, template_path, x: '0.3 cm', y: '0 cm')
          doc.use_template :template

          doc.define_tags do
            tag :grande,      size: 13
            tag :grande_bold, size: 13, name: "Helvetica-Bold"
            tag :pequeno,     size: 6
            tag :super_pequeno, size: 5
          end
        end

        # Monta o cabeçalho do layout do boleto
        def modelo_generico_cabecalho(doc, boleto)
          # INICIO Primeira parte do BOLETO
          # LOGOTIPO do BANCO
          doc.image(boleto.logotipo, x: '0.5 cm', y: '23.88 cm', zoom: 80)
          # Dados
          doc.moveto x: '5.2 cm', y: '23.88 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", tag: :grande
          doc.moveto x: '7.5 cm', y: '23.88 cm'
          doc.show boleto.codigo_barras.linha_digitavel, tag: :grande
          doc.moveto x: '0.7 cm', y: '23.20 cm'
          doc.show boleto.cedente
          doc.moveto :x => '0.7 cm' , :y => '23 cm'
          doc.show boleto.cedente_endereco, :tag => :super_pequeno
          doc.moveto x: '11 cm', y: '23 cm'
          doc.show boleto.agencia_conta_boleto
          doc.moveto x: '14.2 cm', y: '23 cm'
          doc.show boleto.especie
          doc.moveto x: '0.7 cm', y: '22.2 cm'
          doc.show boleto.numero_documento
          doc.moveto x: '7 cm', y: '22.2 cm'
          doc.show "#{boleto.documento_cedente.formata_documento}"
          doc.moveto x: '12 cm', y: '22.2 cm'
          doc.show boleto.data_vencimento.to_s_br
          doc.moveto x: '16.5 cm', y: '23 cm'
          doc.show boleto.nosso_numero_boleto
          doc.moveto x: '16.5 cm', y: '22.2 cm'
          doc.show boleto.valor_documento.to_currency
          doc.moveto x: '0.7 cm', y: '20.75 cm'
          doc.show "#{boleto.sacado} - #{boleto.sacado_documento.formata_documento}" if boleto.sacado && boleto.sacado_documento
          doc.moveto x: '0.7 cm', y: '20.55 cm'
          doc.show "#{boleto.sacado_endereco}", :tag => :pequeno
          doc.text_area boleto.info_recibo_pagador, x: '0.55 cm', y: '19.70 cm', row_height: 0.3, tag: :pequeno
          # FIM Primeira parte do BOLETO
        end

        # Monta o corpo e rodapé do layout do boleto
        def modelo_generico_rodape(doc, boleto)
          # INICIO Segunda parte do BOLETO BB
          # LOGOTIPO do BANCO
          texto_formatado_cedente = "#{boleto.cedente} - #{boleto.documento_cedente.formata_documento}"

          doc.image(boleto.logotipo, x: '0.5 cm', y: '16.85 cm', zoom: 80)
          doc.moveto x: '5.2 cm', y: '16.85 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", tag: :grande_bold
          doc.moveto x: '7.5 cm', y: '16.85 cm'
          doc.show boleto.codigo_barras.linha_digitavel, tag: :grande
          doc.moveto x: '0.7 cm', y: '16 cm'
          doc.show boleto.local_pagamento
          doc.moveto x: '16.5 cm', y: '16 cm'
          doc.show boleto.data_vencimento.to_s_br if boleto.data_vencimento
          doc.moveto x: '0.5 cm', y: '15.36 cm'
          doc.show texto_formatado_cedente, tag: :super_pequeno
          doc.text_in x: '0.5 cm', y: '15.2 cm', tag: :super_pequeno, write: boleto.cedente_endereco
          doc.moveto x: '16.5 cm', y: '15.2 cm'
          doc.show boleto.agencia_conta_boleto
          doc.moveto x: '0.7 cm', y: '14.4 cm'
          doc.show boleto.data_documento.to_s_br if boleto.data_documento
          doc.moveto x: '4.2 cm', y: '14.4 cm'
          doc.show boleto.numero_documento
          doc.moveto x: '10 cm', y: '14.4 cm'
          doc.show boleto.especie_documento
          doc.moveto x: '11.7 cm', y: '14.4 cm'
          doc.show boleto.aceite
          doc.moveto x: '13 cm', y: '14.4 cm'
          doc.show boleto.data_processamento.to_s_br if boleto.data_processamento
          doc.moveto x: '16.5 cm', y: '14.4 cm'
          doc.show boleto.nosso_numero_boleto
          doc.moveto x: '4.4 cm', y: '13.5 cm'
          doc.show boleto.carteira_boleto
          doc.moveto x: '6.4 cm', y: '13.5 cm'
          doc.show boleto.especie
          # doc.moveto :x => '11 cm' , :y => '13.5 cm'
          # doc.show boleto.valor.to_currency
          doc.moveto x: '16.5 cm', y: '13.5 cm'
          doc.show boleto.valor_documento.to_currency
          doc.moveto x: '0.7 cm', y: '12.7 cm'
          doc.text_area boleto.instrucao1, x: '0.7 cm', y: '12.7 cm', row_height: '0.35 cm', width: '14.1 cm'
          doc.moveto x: '1.2 cm', y: '8.8 cm'
          doc.show "#{boleto.sacado} - #{boleto.sacado_documento.formata_documento}" if boleto.sacado && boleto.sacado_documento
          doc.moveto x: '1.2 cm', y: '8.4 cm'
          doc.show "#{boleto.sacado_endereco}"
          # FIM Segunda parte do BOLETO
        end
      end # Base
    end
  end
end
