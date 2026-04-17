/*
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
16/04/2024	ANDERSON WILLIAM			- Atribução dos parâmetros de entrada para as variaveis internas, evita o "parameter sniffing" do SQL SERVER;
										- Alteração do prefixo do nome de "SP_" para "usp_";
										- Uso da SP "usp_GetTabelaEmpresa";
										- Troca da tabela TBS117 pela TBS143;
************************************************************************************************************************************************************************************
*/
create procedure [dbo].[usp_GetNotasDevolucaoItinerario] (
	@empresa int,
	@dataEmissaoDe datetime,
	@dataEmissaoAte datetime,
	@numeroNotaDe int,
	@numeroNotaAte int, 
	@serie int, 
	@pular int,
	@textoPesquisar varchar(60),
	@numeroItinerario int,
	@ordenarClassificar varchar(50)
)
As Begin 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	declare @codigoEmpresa int,	@datEmissaoDe datetime, @datEmissaoAte datetime, @numNotaDe int, @numNotaAte int, 
			@SNESER int, @pul int, @texPesquisar varchar(60), @numItinerario int,@ordClassificar varchar(50),

			@empresaTBS143 int, @empresaTBS080 int, @empresaTBS006 int, @empresaTBS109 int
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições internas
	SET @codigoEmpresa = @empresa
	SET @datEmissaoDe = @dataEmissaoDe
	SET @datEmissaoAte = @dataEmissaoAte
	SET @numNotaDe = @numeroNotaDe
	SET @numNotaAte = @numeroNotaAte
	SET @SNESER = @serie
	SET @pul = @pular
	SET @texPesquisar = @textoPesquisar
	SET @numItinerario = @numeroItinerario
	SET @ordClassificar = @ordenarClassificar

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva	
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS143', @empresaTBS143 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS080', @empresaTBS080 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS006', @empresaTBS006 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS109', @empresaTBS109 output;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Somente as notas de devolução e autorizadas (atributos necessarios)

	If object_id('tempdb.dbo.#NotasAutorizadas') is not null
		drop table #NotasAutorizadas	
	
	select 
	A.ENFNUM as numeroNotaDevolucao,
	A.SNEEMPCOD as empresaSerie,
	A.SNESER as numeroSerie,
	A.ENFCODDES as codigoFornecedor,
	A.ENFVENCOD as codigoVendedor, 
	A.ENFVALTOT as valorNotaDevolucao,
	A.ENFCHAACE as chaveNota
	
	into #NotasAutorizadas

	from TBS080 A (nolock)
	
	where 
	A.ENFEMPCOD = @empresaTBS080 AND 
	A.ENFDATEMI between @datEmissaoDe AND @datEmissaoAte AND 
	A.ENFSIT = 6 AND -- somente autorizada
	A.ENFFINEMI = 4 AND  -- somente de devolução
	A.ENFTIPDOC = 1 AND -- somente saida
	A.ENFNUM between @numNotaDe AND @numNotaAte and
	A.SNESER = case when @SNESER = 0 then A.SNESER else @SNESER end
	
	order by 
	A.ENFEMPCOD,
	A.ENFDATEMI,
	A.ENFSIT,
	A.ENFFINEMI,
	A.ENFNUM,
	A.SNESER	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Fazer uma temp dos municipois pois vou acessar mais que 1 vez
	
	If object_id('tempdb.dbo.#Municipios') is not null
		drop table #Municipios
	
	select 
	A.MUNCOD as codigoMunicipio,
	rtrim(A.MUNNOM) as nomeMunicipio	
	
	into #Municipios
	from TBS003 A (nolock)
	
	order by 
	A.MUNCOD	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Somente os fornecedores utilizados (atributos necessarios)
	
	If object_id('tempdb.dbo.#Fornecedores') is not null
		drop table #Fornecedores
	
	select 
	A.FORCOD as codigoFornecedor,
	rtrim(A.FOREND) as logradouroDevolucaoFornecedor,
	rtrim(A.FORNUM) as numeroDevolucaoFornecedor,
	rtrim(A.FORBAI) as bairroDevolucaoFornecedor,
	rtrim(A.FORCPLEND) as complementoEntrega,
	-- isnull(C.nomeRegiao,'') as regiaoDevolucaoFornecedor,
	isnull(B.nomeMunicipio,'') as municipioDevolucaoFornecedor,
	A.UFESIG as ufDevolucaoFornecedor,
	rtrim(A.FORNOMFAN) as nomeFantasiaFornecedor
	
	into #Fornecedores

	from TBS006 A (nolock)
	left join #Municipios B (nolock) on A.MUNCOD = B.codigoMunicipio
	
	where 
	A.FOREMPCOD = @empresaTBS006 AND 
	A.FORCOD in (select distinct codigoFornecedor from #NotasAutorizadas)
	
	order by 
	A.FOREMPCOD,
	A.FORCOD
	
	-- select * from #Fornecedores
		
	-----------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Carregar notas do itinerario, com o numero do itinerario em ordem descrescente
	
	If object_id('tempdb.dbo.#Itinerario') is not null
		drop table #Itinerario
	
	select 
	row_number() over (partition by A.ITISERDOC, A.ITIDOCNUM order by A.ITINUM desc) as rank,	
	A.ITINUM as numeroItinerario,
	A.ITISERDOC as serieDocumentoItinerario,
	A.ITIDOCNUM as numeroDocumentoItinerario, 
	A.ITISTAITE as statusItem
	
	into #Itinerario

	from TBS1091 A (nolock) 
	
	where 
	A.ITIEMPCOD = @empresaTBS109 AND 
	A.ITIEMPDOC = @empresaTBS143 AND
	A.ITIDOCNUM IN (select numeroNotaDevolucao from #NotasAutorizadas)
	
	order by 
	A.ITIEMPCOD,
	A.ITIEMPDOC,
	A.ITIDOCNUM
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Pegar o ultimo itinerario das notas
	
	if object_id('tempdb.dbo.#NotasItinerario') is not null
	begin 
		drop table #NotasItinerario
	end
	
	select 
	numeroItinerario,
	serieDocumentoItinerario,
	numeroDocumentoItinerario,
	statusItem
	
	into #NotasItinerario

	from #Itinerario
	
	where 
	rank = 1
	
	order by 
	rank
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Pegar as notas de saida TBS067 (atributos necessarios)
	
	if object_id('tempdb.dbo.#NotasDevolucao') is not null
	begin 
		drop table #NotasDevolucao
	end		
	
	select 
	A.FORCOD as codigoFornecedor,
	0 as empresaSerie,
	A.NDFSNESER as numeroSerie,
	numeroItinerario,
	statusItem,
	A.NDFEMPCOD as empresaNotaDevolucao, 	-- ITIEMPDOC,
	A.NDFENFNUM as numeroNotaDevolucao,			-- ITIDOCNUM,
	A.NDFDATEMI as emissaoNotaDevolucao,		-- ITIEMIDOC,
	A.NDFVOLQTD as volumeNotaDevolucao,		-- ITIQTDVOL,
	A.NDFPESBRU as pesoBrutoNotaDevolucao,	-- ITIPESBRU,
	A.NDFPESLIQ as pesoLiquidoNotaDevolucao,	-- ITIPESLIQ,
	rtrim(A.NDFFORNOM) as nomeFornecedorNotaDevolucao -- ITINOMDES,
	
	into #NotasDevolucao

	from TBS143 A (nolock) 
	left join #NotasItinerario B on A.NDFSNESER = B.serieDocumentoItinerario AND A.NDFENFNUM = B.numeroDocumentoItinerario
	
	where 
	A.NDFEMPCOD = @empresaTBS143 AND 
	A.NDFDATEMI between @datEmissaoDe AND @datEmissaoAte AND 
	A.NDFENFNUM in (select numeroNotaDevolucao from #NotasAutorizadas) AND 
	A.FORCOD in (select codigoFornecedor from #Fornecedores)
	
	order by 
	NDFEMPCOD,
	NDFDATEMI,
	NDFENFNUM,
	FORCOD
	
	-- select * from #NotasDevolucao
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Eliminar notas já entregue 
	
	delete #NotasDevolucao where statusItem = 'E'
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Tabela final de apresentacao no dataGridView 
	
	if object_id('tempdb.dbo.#GetNotasDevolucao1') is not null
	begin 
		drop table #GetNotasDevolucao1
	end	
	
	-- Deixar as colunas na sequencia que irá aprecer na grid no c#vs
	select 
	a.empresaNotaDevolucao, -- ficará oculto
	isnull(a.numeroItinerario,0) as numeroItinerario,
	a.numeroSerie,
	a.numeroNotaDevolucao,
	b.valorNotaDevolucao,	
	a.volumeNotaDevolucao, -- congela até aqui 
	
	c.nomeFantasiaFornecedor,
	a.codigoFornecedor,
	
	c.bairroDevolucaoFornecedor,
	
	c.municipioDevolucaoFornecedor,
	c.ufDevolucaoFornecedor,
	
	a.nomeFornecedorNotaDevolucao,
	a.emissaoNotaDevolucao,	
	a.pesoBrutoNotaDevolucao,
	a.pesoLiquidoNotaDevolucao,
	
	b.chaveNota
	
	into #GetNotasDevolucao1

	from #NotasDevolucao a (nolock)
	inner join #NotasAutorizadas b (nolock) on a.numeroNotaDevolucao = b.numeroNotaDevolucao AND a.numeroSerie = b.numeroSerie AND 
											   a.codigoFornecedor = b.codigoFornecedor
	left join #Fornecedores c on a.codigoFornecedor = c.codigoFornecedor
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Excluir documento já inserido no itinerario que está sendo editado

	delete #GetNotasDevolucao1 where numeroItinerario = @numItinerario
	
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Tabela final 
	
	if object_id('tempdb.dbo.#GetNotasDevolucao') is not null
	begin 
		drop table #GetNotasDevolucao
	end
	
	create table #GetNotasDevolucao (
	empresaNotaDevolucao int,
	ultimoItinerario int,
	numeroSerie int,
	numeroNotaDevolucao int,
	valorNotaDevolucao money,	
	volumeNotaDevolucao int,
	nomeFantasiaFornecedor varchar(60),
	codigoFornecedor int,
	bairroDevolucaoFornecedor varchar(60),
	municipioDevolucaoFornecedor varchar(35),
	ufDevolucaoFornecedor char(2),
	nomeFornecedorNotaDevolucao varchar(60),
	emissaoNotaDevolucao datetime,	
	pesoBrutoNotaDevolucao smallmoney,
	pesoLiquidoNotaDevolucao smallmoney,
	chaveNota char(44) )
	
	if len(@texPesquisar) > 0	

	begin	
	
		insert #GetNotasDevolucao
		
		select * 
		
		from #GetNotasDevolucao1 
		
		where 
		nomeFantasiaFornecedor like ('%' + @texPesquisar + '%') or
		bairroDevolucaoFornecedor like ('%' + @texPesquisar + '%') or 
		municipioDevolucaoFornecedor like ('%' + @texPesquisar + '%') or
		ufDevolucaoFornecedor like ('%' + @texPesquisar + '%') or
		nomeFornecedorNotaDevolucao like ('%' + @texPesquisar + '%') 
		
		order by 
		empresaNotaDevolucao,
		numeroSerie, 
		numeroNotaDevolucao 
		
		-- offset @pular rows fetch next 30 rows only
	end
	
	else
	
	begin

		insert #GetNotasDevolucao
		
		select * 
		
		from #GetNotasDevolucao1 
		
		order by 
		empresaNotaDevolucao,
		numeroSerie, 
		numeroNotaDevolucao 
		
		-- offset @pular rows fetch next 30 rows only
	
	end
		
	-----------------------------------------------------------------------------------------------------------------------------------------------------------
	
	-- Filtro de ordenação na tabela final 
	
	Declare @selectOrdem varchar(500)
	
	set @selectOrdem = 'select * from #GetNotasDevolucao Order by empresaNotaDevolucao, ' + @ordClassificar + ' offset ' + ltrim(str(@pul)) + ' rows fetch next 30 rows only'
	
	EXEC(@selectOrdem)

	-----------------------------------------------------------------------------------------------------------------------------------------------------------
end
GO


