/*
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
16/04/2024	ANDERSON WILLIAM			- Atribução dos parâmetros de entrada para as variaveis internas, evita o "parameter sniffing" do SQL SERVER;
										- Alteração do prefixo do nome de "SP_" para "usp_";
										- Uso da SP "usp_GetTabelaEmpresa";									
************************************************************************************************************************************************************************************
*/
alter procedure [dbo].[usp_GetNotasSaidaItinerario](
	@empresa int,
	@dataEmissaoDe datetime,
	@dataEmissaoAte datetime,
	@numeroNotaDe int,
	@numeroNotaAte int,
	@serie int,
	@pular int,
	@textoPesquisar varchar(60),
	@numeroItinerario int,
	@ordenarClassificar varchar(50),
	@opcao int, 
	@ChaveNFe varchar(44)
)
As Begin 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	declare @codigoEmpresa int,	@datEmissaoDe datetime, @datEmissaoAte datetime, @numNotaDe int, @numNotaAte int, 
			@SNESER int, @pul int, @texPesquisar varchar(60), @numItinerario int,@ordClassificar varchar(50), @op int, @ChaNFe varchar(44),

	
			@empresaTBS067 int, @empresaTBS080 int, @empresaTBS097 int, @empresaTBS004 int, @empresaTBS002 int, @empresaTBS109 int, 
			@select_TBS067 varchar(2000), @from_TBS067 varchar(2000), @where_TBS067 varchar(2000), @order_TBS067 varchar(2000)
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
	SET @op = @opcao
	SET @ChaNFe = @ChaveNFe
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS067', @codigoEmpresa = @empresaTBS067 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS080', @codigoEmpresa = @empresaTBS080 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS097', @codigoEmpresa = @empresaTBS097 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @codigoEmpresa = @empresaTBS004 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @codigoEmpresa = @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS109', @codigoEmpresa = @empresaTBS109 output;
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Somente as notas de saida e autorizadas (atributos necessarios)
	-- Ainda venho na TBS080, por já ter o valor das notas em um atributo, na TBS067, tenho que pegar a formula NFSTOTLIQ, dessa forma fica mais lento.

	If object_id('tempdb.dbo.#NotasAutorizadas') is not null
		drop table #NotasAutorizadas
	
	select 
	A.ENFNUM as numeroNota,
	A.SNEEMPCOD as empresaSerie,
	A.SNESER as numeroSerie,
	A.ENFCODDES as codigoCliente,
	A.ENFVENCOD as codigoVendedor, 
	A.ENFVALTOT as valorNota,
	A.ENFCHAACE as chaveNota
	
	into #NotasAutorizadas

	from TBS080 A (nolock)
	
	where 
	A.ENFEMPCOD = @empresaTBS080 and 
	A.ENFCHAACE = case when @ChaNFe = '' then A.ENFCHAACE else @ChaNFe end and
	A.ENFDATEMI between @datEmissaoDe and @datEmissaoAte and 
	A.ENFSIT = 6 and -- somente autorizada
	A.ENFFINEMI = 1 and  -- somente de saida	
	A.ENFNUM between @numNotaDe and @numNotaAte and 
	A.SNESER = case when @SNESER = 0 then A.SNESER else @SNESER end
	
	order by 
	A.ENFEMPCOD,
	A.ENFDATEMI,
	A.ENFSIT,
	A.ENFFINEMI,
	A.ENFNUM,
	A.SNESER	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Somente os vendedores utilizados (atributos necessarios)
	
	If object_id('tempdb.dbo.#Vendedores') is not null
		drop table #Vendedores
	
	select 
	VENEMPCOD as empresaVendedor,
	VENCOD as codigoVendedor,
	ltrim(str(VENCOD)) + ' - ' + rtrim(VENNOM) as nomeVendedor
	
	into #Vendedores

	from TBS004 A (nolock)
	
	where 
	A.VENEMPCOD = @empresaTBS004 and 
	A.VENCOD in (select distinct codigoVendedor from #NotasAutorizadas)
	
	order by
	A.VENEMPCOD,
	A.VENCOD	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Fazer uma temp das regioes pois vou acessar mais que 1 vez
	
	If object_id('tempdb.dbo.#Regioes') is not null
		drop table #Regioes
	
	select 
	RDVCOD as codigoRegiao,
	rtrim(RDVDES) as nomeRegiao,
	RDVUFESIG as ufRegiao
	
	into #Regioes

	from TBS097 A (nolock) 
	
	where 
	A.RDVEMPCOD = @empresaTBS097
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Somente os clientes utilizados (atributos necessarios)
	
	If object_id('tempdb.dbo.#Clientes') is not null
		drop table #Clientes
	
	select
	A.CLIEMPCOD as empresaCliente,
	A.CLICOD as codigoCliente,
	rtrim(A.CLIBAI) as bairroFaturamentoCliente,
	isnull(C.nomeRegiao,'') as regiaoFaturamentoCliente,
	rtrim(A.CLINOMFAN) as nomeFantasiaCliente
	
	into #Clientes

	from TBS002 A (nolock)
	left join #Regioes C (nolock) on A.RDVCOD = C.codigoRegiao and A.UFESIG = C.ufRegiao
	
	where 
	A.CLIEMPCOD = @empresaTBS002 and 
	A.CLICOD in (select distinct codigoCliente from #NotasAutorizadas)
	
	order by 
	A.CLIEMPCOD,
	A.CLICOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Somente o enderco de entrega dos clientes 
	
	If object_id('tempdb.dbo.#ClientesEntrega') is not null
		drop table #ClientesEntrega
	
	select 
	A.CLIEMPCOD as empresaCliente,
	A.CLICOD as codigoCliente,
	A.CLIENDCOD as codigoEntregaCliente,
	isnull(C.nomeRegiao,'') as regiaoEntregaCliente
	
	into #ClientesEntrega

	from TBS0021 A (nolock)
	left join #Regioes C (nolock) on A.CLIRDVCOD = C.codigoRegiao and A.CLIENDUFE = C.ufRegiao
	
	where 
	A.CLIEMPCOD = @empresaTBS002 and 
	A.CLICOD in (select distinct codigoCliente from #NotasAutorizadas) and 
	CLIENDTIP = 'E'
	
	order by 
	A.CLIEMPCOD,
	A.CLICOD,
	CLIENDTIP
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Tabela Notas de saida
	
	If object_id('tempdb.dbo.#NotasSaidaAutorizadas') is not null
		drop table #NotasSaidaAutorizadas
	
	select 
	@empresaTBS067 as empresaNota,
	[dbo].[ufn_GetUltimoItinerarioDocumentoEntregue](@empresaTBS109, @empresaTBS067, B.NFSTIP, B.NFSNUM, B.SNESER, 0) as ultimoItinerario,
	B.SNESER as serieNota,
	B.NFSNUM as numeroNota,
	A.valorNota as valorNota,
	B.NFSVOLQTD as volumeNota, 
	
	B.NFSCLIEMP as empresaCliente,
	B.NFSCLICOD as codigoCliente,
	
	B.NFSENDENTCOD as codigoEntregaCliente,
	B.NFSENTBAI as bairroEntregaNota,
	
	case when B.NFSENDENTCOD > 0
		then B.NFSENTMUN
		else B.NFSMUNNOM
	end as municipioEntregaNota,
	
	case when B.NFSENDENTCOD > 0 
		then B.NFSENTUFE
		else B.UFESIG
	end as ufEntregaNota,
	
	rtrim(B.NFSCLINOM) as nomeClienteNota,
	B.NFSDATEMI as emissaoNota,	
	B.NFSPESBRU as pesoBrutoNota,
	B.NFSPESLIQ as pesoLiquidoNota,
	B.NFSTIP as tipoNota,
	B.VENCOD as codigoVendedor,
	B.VENEMPCOD as empresaVendedor,
	A.chaveNota
	
	into #NotasSaidaAutorizadas

	from #NotasAutorizadas A (nolock)
	inner join TBS067 B (nolock) on B.NFSEMPCOD = @empresaTBS067 and A.numeroNota = B.NFSNUM and A.empresaSerie = B.SNEEMPCOD and A.numeroSerie = B.SNESER
	
	where 
	B.NFSEMPCOD = @empresaTBS067 and 
	[dbo].[ufn_GetItinerarioContemDocumento](@empresaTBS109, @numItinerario, @empresaTBS067, B.NFSTIP, B.NFSNUM, B.SNESER, 0) = 0 
	
	order by 
	B.NFSEMPCOD,
	B.NFSDATEMI,
	B.NFSNUM,
	B.SNEEMPCOD,
	B.SNESER,
	B.NFSENFSIT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Criaçao da tabela final 
	
	If object_id('tempdb.dbo.#GetNotasSaida') is not null
		drop table #GetNotasSaida
	
	create table #GetNotasSaida (
		empresaNota int, -- Esse campo ficara oculto.
		ultimoItinerario char(30),
		serieNota int, 
		numeroNota int,
		valorNota money,
		volumeNota int, -- na tela para o usuario congelar até aqui.
		nomeFantasiaCliente varchar(60),
		codigoCliente int,
		bairroEntregaNota varchar(60),
		regiaoEntregaNota varchar(60),
		municipioEntregaNota varchar(60),
		ufEntregaNota char(2), 
		nomeClienteNota varchar(60),
		emissaoNota datetime, 
		pesoBrutoNota money,
		pesoLiquidoNota money,
		tipoNota char(1),
		nomeVendedor varchar(60),
		chaveNota varchar(44)
	)	
	
	set @select_TBS067 = '
	select 
	A.empresaNota,
	A.ultimoItinerario,
	A.serieNota,
	A.numeroNota,
	A.valorNota,
	A.volumeNota,
	
	isnull(C.nomeFantasiaCliente,'''') as nomeFantasiaCliente,
	A.codigoCliente,
	
	case when A.codigoEntregaCliente > 0 
		then rtrim(A.bairroEntregaNota)
		else rtrim(C.bairroFaturamentoCliente)
	end as bairroEntregaNota,
	
	case when A.codigoEntregaCliente > 0 
		then isnull(D.regiaoEntregaCliente, '''')
		else isnull(C.regiaoFaturamentoCliente, '''')
	end as regiaoEntregaNota,
	
	A.municipioEntregaNota,
	A.ufEntregaNota,
	A.nomeClienteNota,
	A.emissaoNota,	
	A.pesoBrutoNota,
	A.pesoLiquidoNota,
	A.tipoNota,
	isnull(nomeVendedor,'''') as nomeVendedor,
	A.chaveNota '
	
	set @from_TBS067 = '
	from #NotasSaidaAutorizadas A (nolock)
	left join #Clientes C (nolock) on A.empresaCliente = C.empresaCliente and A.codigoCliente = C.codigoCliente 
	left join #ClientesEntrega D (nolock) on A.empresaCliente = D.empresaCliente and A.codigoCLiente = D.codigoCliente and A.codigoEntregaCliente = D.codigoEntregaCliente
	left join #Vendedores E (nolock) on A.empresaVendedor = E.empresaVendedor and A.codigoVendedor = E.codigoVendedor '
	
	set @where_TBS067 = '
	where 
	(
	isnull(C.nomeFantasiaCliente,'''') like (''%' + @texPesquisar + '%'') or 
	
	case when A.codigoEntregaCliente > 0 
		then rtrim(A.bairroEntregaNota)
		else rtrim(C.bairroFaturamentoCliente)
	end like (''%' + @texPesquisar + '%'') or 
	
	case when A.codigoEntregaCliente > 0 
		then D.regiaoEntregaCliente 
		else C.regiaoFaturamentoCliente
	end like (''%' + @texPesquisar + '%'') or 
	
	A.municipioEntregaNota like (''%' + @texPesquisar + '%'') or 
	A.ufEntregaNota like (''%' + @texPesquisar + '%'') or 
	A.nomeClienteNota like (''%' + @texPesquisar + '%'') or 
	isnull(nomeVendedor,'''') like (''%' + @texPesquisar + '%'')  ) '
	
	if @op = 0 -- Pegar de 30 em 30 notas
	
	begin 
		set @order_TBS067 = ' Order by ' + @ordClassificar + ' , A.empresaNota offset ' + ltrim(str(@pul)) + ' rows fetch next 30 rows only'
	end
	
	else 
	
	begin 
		set @order_TBS067 = ' Order by ' + @ordClassificar + ', A.empresaNota '
	end

	insert into #GetNotasSaida
	exec (@select_TBS067 + @from_TBS067 + @where_TBS067 + @order_TBS067 )	
	
	select * from #GetNotasSaida
	
end
GO


