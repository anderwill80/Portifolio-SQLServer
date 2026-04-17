/*
======================================================================================================================================================
Script do Report Server					 Or�amentos e Pedidos por data e hora
======================================================================================================================================================
										Hist�rico de altera��es
======================================================================================================================================================
Data		Por							Descri��o
**********	********************		**************************************************************************************************************
06/08/2024	ANDERSON WILLIAM			- Troca das fun��es ORCTOTLIQ e PDVTOTLIQ pelas ufn_ORCTOTLIQ e ufn_PDVTOTLIQ respectivamente;
										para corrigir problema de estouro da capacidade

05/08/2024	ANDERSON WILLIAM			- Convers�o para Stored Procedure
******************************************************************************************************************************************************
*/
--alter proc [dbo].usp_RS_OrcamentosPedidosDataHora(
create proc [dbo].usp_RS_OrcamentosPedidosDataHora(
	@empcod smallint,
	@dataDe date,
	@dataAte date = null,
	@codigoVendedor varchar(800),
	@nomeVendedor varchar(100),
	@grupoVendedor varchar(500),
	@codigoCliente int,	
	@nomeCliente varchar(50),
	@grupo char(1),
	@tipo char(10)
	)
as
begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declara��es das variaveis locais

	DECLARE	@empresaTBS002 smallint, @empresaTBS004 smallint, @Query nvarchar (MAX), @ParmDef nvarchar (500),
			@empresa smallint, @Data_De date, @Data_Ate date, @vendedor varchar(800), @nVendedor varchar(100), @gVendedor varchar(500), 
			@CLICOD int, @CLINOM varchar(50), @cligrupo char(1), @tipoTran char(10),
			@CodigoDevolucao int
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribui��es para desabilitar o "Parameter Sniffing" do SQL

	SET @empresa = @empcod
	SET @Data_De = @dataDe
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()))
	SET @vendedor = REPLACE(@codigoVendedor, ' ','')
	SET @nVendedor = RTRIM(UPPER(@nomeVendedor))
	SET @gVendedor = @grupoVendedor
	SET @cligrupo = @grupo
	SET @CLICOD = @codigoCliente	
	SET @CLINOM = UPPER(RTRIM(LTRIM(@nomeCliente)))
	SET @tipoTran = @tipo

	SET @CodigoDevolucao = (SELECT RTRIM(LTRIM(PARVAL)) FROM TBS025 (NOLOCK) WHERE PARCHV = 1330)

	-- Quebra os filtros Multi-valores em tabelas via fun��o "Split", para facilitar a cl�usula "IN()"

	-- Vendedores do par�metro
	If object_id('TempDB.dbo.#Vendedor_Parm') is not null
		DROP TABLE #Vendedor_Parm
    select elemento as [codven]
	Into #Vendedor_Parm
    From fSplit(@vendedor, ',')

	If object_id('TempDB.dbo.#GrupoVendedor_Parm') is not null
		DROP TABLE #GrupoVendedor_Parm
    select elemento as [codgruven]
	Into #GrupoVendedor_Parm
    From fSplit(@gVendedor, ',')

	If object_id('TempDB.dbo.#TiposTran') is not null
		DROP TABLE #TiposTran

    select elemento as [tipo]
	Into #TiposTran
    From fSplit(@tipoTran, ',')

	-- Verificar se a tabela � compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS004', @empresaTBS004 output;	
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Monta query dinamica

	If object_id('tempdb.dbo.#T') is not null
		drop table #T;

	create table #T (VENCOD INT)

	SET @Query = N'
				INSERT INTO #T

				SELECT VENCOD 				
				FROM TBS004 (NOLOCK)
				WHERE
				VENEMPCOD = @empresaTBS004
				'
				+
				iif(@vendedor = '', '', ' AND VENCOD IN (SELECT codven from #Vendedor_Parm)')
				+
				'UNION 
				SELECT TOP 1 0 FROM TBS001 (NOLOCK)
				'
				+
				iif(@vendedor = '', '', ' WHERE 0 IN (SELECT codven from #Vendedor_Parm)')
			    
	-- Executa a Query din�minca(QD)
	SET @ParmDef = N'@empresaTBS004 smallint'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS004

--	SELECT * FROM #T
------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- TABELA DE VENDEDOR 

	if object_id('tempdb.dbo.#Vendedores') is not null
	   drop table #Vendedores;

	SELECT 
	VENCOD as codigoVendedor,
	RTRIM(LTRIM(STR(B.VENCOD))) + ' - ' + RTRIM(LTRIM(VENNOM)) AS nomeVendedor,
	B.GVECOD as codigoGrupo,
	ISNULL(RTRIM(LTRIM(STR(B.GVECOD))) + ' - ' + RTRIM(LTRIM(C.GVEDES)), '0 - SEM GRUPO') AS nomeGrupo

	INTO #Vendedores
	FROM TBS004 B (NOLOCK)
	LEFT JOIN TBS091 C (NOLOCK) ON B.GVECOD = C.GVECOD AND B.GVEEMPCOD = C.GVEEMPCOD

	WHERE
	VENCOD IN (SELECT VENCOD FROM #T) AND 
	RTRIM(LTRIM(VENNOM)) LIKE (CASE WHEN @nVendedor = '' THEN RTRIM(LTRIM(VENNOM)) ELSE @nVendedor END) and 
	B.GVECOD IN (SELECT codgruven from #GrupoVendedor_Parm)

	UNION

	SELECT
	TOP 1 
	0,
	'0 - SEM VENDEDOR' AS VENNOM,
	0,
	'0 - SEM GRUPO' AS GVDES

	FROM TBS001 (NOLOCK)

	WHERE
	0 IN (SELECT VENCOD FROM #T) AND 
	'SEM VENDEDOR' LIKE (CASE WHEN @nVendedor = '' THEN 'SEM VENDEDOR' ELSE @nVendedor END) and 
	0 IN (SELECT codgruven from #GrupoVendedor_Parm)

 -- select * from #Vendedores
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obter clientes do grupo

	if object_id('tempdb.dbo.#TBS002GRU') is not null
		drop table #TBS002GRU;

	CREATE TABLE #TBS002GRU (codigoCliente INT, nomeCliente varchar(60))

	if object_id('tempdb.dbo.#CodigosClienteGrupo') is not null
		drop table #CodigosClienteGrupo;

	create table #CodigosClienteGrupo (codigo int)

	insert into #CodigosClienteGrupo
	exec usp_ClientesGrupo @empresa 

	-- Query din�mica
	IF @cligrupo = 'N'
	Begin
		SET @Query = N'
			INSERT INTO #TBS002GRU

			SELECT TOP 1
			-1, 
			''''
			FROM TBS002 (NOLOCK)
			'
	End
	Else
	Begin
		set @Query = N'
			INSERT INTO #TBS002GRU

			SELECT 
			CLICOD,
			CLINOM

			FROM TBS002 (NOLOCK) 

			WHERE 
			CLIEMPCOD = @empresaTBS002 AND
			CLICOD in (select codigo from #CodigosClienteGrupo)
			'
			+
			IIF(@CLICOD <= 0, '', ' AND CLICOD = @CLICOD')
			+			
			IIF(@CLINOM = '', '', ' AND CLINOM LIKE @CLINOM')
	End

	-- Executa a Query din�minca(QD)
	SET @ParmDef = N'@empresaTBS002 smallint, @CLICOD int, @CLINOM varchar(50)'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS002, @CLICOD, @CLINOM

	-- SELECT * FROM #TBS002GRU
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CLIENTES SEM O GRUPO SEMPRE VAI EXISTIR 

	If object_id('tempdb.dbo.#Clientes') is not null
		drop table #Clientes;

	--  SELECT TOP 0, para criar a estrutura da tabela
	SELECT TOP 0
	CLICOD as codigoCliente,
	RTRIM(LTRIM(CLINOM)) collate database_default AS nomeCliente

	INTO #Clientes

	FROM TBS002 (nolock)

	SET @Query = N'
		INSERT INTO #Clientes
				
		SELECT
		CLICOD as codigoCliente,
		RTRIM(LTRIM(CLINOM)) collate database_default AS nomeCliente
	
		FROM TBS002 (nolock)
		WHERE 
		CLIEMPCOD = @empresaTBS002 AND
		CLICOD NOT IN (select codigo from #CodigosClienteGrupo)
		'
		+
		IIF(@CLICOD <= 0, '', ' AND CLICOD = @CLICOD')
		+			
		IIF(@CLINOM = '', '', ' AND CLINOM LIKE @CLINOM')	
		+
		'
		UNION
		select 
		*
		FROM #TBS002GRU
		WHERE
		codigoCliente NOT IN (@CodigoDevolucao)
		'
	-- Executa a Query din�minca(QD)
	SET @ParmDef = N'@empresaTBS002 smallint, @CLICOD int, @CLINOM varchar(50), @CodigoDevolucao int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS002, @CLICOD, @CLINOM, @CodigoDevolucao

--	SELECT * FROM #Clientes
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- filtrar os or�amentos 

	If object_id('tempdb.dbo.#Orcamento') is not null
		drop table #Orcamento;

	SELECT 
	'O' as tipo,
	VENCOD as codigoVendedor,
	ORCDATCAD as data,
	subString(SUBSTRING(ORCUSUGER,12,5),1,2)+':00'+'~'+subString(SUBSTRING(ORCUSUGER,12,5),1,2)+':59' as hora,
	ROUND(dbo.[ufn_ORCTOTLIQ](A.ORCEMPCOD,A.ORCNUM), 2) AS valorTotal,
	ROW_NUMBER() OVER( PARTITION BY ORCCLI, ORCDATCAD, subString(SUBSTRING(ORCUSUGER,12,5),1,2)+':00'+'~'+subString(SUBSTRING(ORCUSUGER,12,5),1,2)+':59' ORDER BY ORCNUM ) as qtdClientesHora,
	ROW_NUMBER() OVER( PARTITION BY ORCCLI, ORCDATCAD ORDER BY ORCNUM ) as qtdClientesDia,
	ROW_NUMBER() OVER( PARTITION BY ORCCLI ORDER BY ORCNUM ) as qtdClientesPeriodo,
	ORCCLI AS codigoCliente,
	nomeCliente,
	ORCNUM AS numero,
	ISNULL((select count(*) from TBS0431 c (nolock) where A.ORCEMPCOD = c.ORCEMPCOD and A.ORCNUM = c.ORCNUM group by c.ORCNUM), 0) as quantidadeItens

	INTO #Orcamento

	FROM TBS043 A (NOLOCK) 
	inner join #Clientes B On A.ORCCLI = B.codigoCliente

	where 
	ORCDATCAD BETWEEN @Data_De and @Data_Ate AND 
	VENCOD IN (SELECT codigoVendedor FROM #Vendedores) AND 
	ORCCLI IN (SELECT codigoCliente FROM #Clientes) AND
	'O' in(select tipo from #TiposTran)

	ORDER BY 
	ORCNUM  

--	select * from #Orcamento
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- filtrar os pedidos

	If object_id('tempdb.dbo.#Pedido') is not null
		drop table #Pedido;

	SELECT 
	'P' as tipo,
	VENCOD as codigoVendedor,
	PDVDATCAD as data,
	subString(SUBSTRING(PDVUSUGER,12,5),1,2)+':00'+'~'+subString(SUBSTRING(PDVUSUGER,12,5),1,2)+':59' as hora,
	ROUND(dbo.[ufn_PDVTOTLIQ](A.PDVEMPCOD,A.PDVNUM), 2) AS valorTotal,
	ROW_NUMBER() OVER( PARTITION BY PDVCLICOD, PDVDATCAD, subString(SUBSTRING(PDVUSUGER,12,5),1,2)+':00'+'~'+subString(SUBSTRING(PDVUSUGER,12,5),1,2)+':59' ORDER BY PDVNUM ) as qtdClientesHora,
	ROW_NUMBER() OVER( PARTITION BY PDVCLICOD, PDVDATCAD ORDER BY PDVNUM ) as qtdClientesDia,
	ROW_NUMBER() OVER( PARTITION BY PDVCLICOD ORDER BY PDVNUM ) as qtdClientesPeriodo,
	PDVCLICOD AS codigoCliente,
	nomeCliente,
	PDVNUM AS numero,
	ISNULL((select count(*) from TBS0551 c (nolock) where A.PDVEMPCOD = c.PDVEMPCOD and A.PDVNUM = c.PDVNUM group by c.PDVNUM), 0) as quantidadeItens

	INTO #Pedido
	FROM TBS055 A (NOLOCK) 
	inner join #Clientes B On A.PDVCLICOD = B.codigoCliente

	where 
	PDVDATCAD BETWEEN @Data_De AND @Data_Ate AND 
	VENCOD IN (SELECT codigoVendedor FROM #Vendedores) AND 
	PDVCLICOD IN (SELECT codigoCliente FROM #Clientes) AND
	'P' in(select tipo from #TiposTran)

	ORDER BY 
	PDVNUM  

--	SELECT * FROM #Pedido
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- juntar os orcamentos e pedidos; criar um filtro para escolher um dos dois ou os dois; mostrar no reports de forma separada, dois agrupamentos diferentes

	If object_id('tempdb.dbo.#OrcamentoPedido') is not null
		drop table #OrcamentoPedido;

	SELECT
	*	
	INTO #OrcamentoPedido

	FROM #Orcamento

	UNION 

	SELECT 
	* 
	FROM #Pedido

	update #OrcamentoPedido set
	qtdClientesPeriodo = case when qtdClientesPeriodo > 1 then 0 else qtdClientesPeriodo end ,
	qtdClientesDia = case when qtdClientesDia > 1 then 0 else qtdClientesDia end ,
	qtdClientesHora = case when qtdClientesHora > 1 then 0 else qtdClientesHora end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	select 
	tipo,
	A.codigoGrupo,
	A.codigoVendedor,
	nomeGrupo,
	nomeVendedor,
	data,
	hora,
	valorTotal,
	qtdClientesHora,
	qtdClientesDia,
	qtdClientesPeriodo,
	codigoCliente,
	nomeCliente,
	numero,
	quantidadeItens

	from #Vendedores A 
	inner join #OrcamentoPedido B on A.codigoVendedor = B.codigoVendedor

End