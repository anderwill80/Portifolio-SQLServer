/*
====================================================================================================================================================================================
WREL010 - Compras por comprador
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
16/01/2025 - WILLIAM
	- Alteração nos parametros da SP "usp_FornecedoresGrupo";
08/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Uso da SP "usp_FornecedoresGrupo" em vez da "sp_FornecedoresGrupo"
************************************************************************************************************************************************************************************
*/
--CREATE PROCEDURE [dbo].[usp_RS_ComprasPorComprador]
ALTER PROCEDURE [dbo].[usp_RS_ComprasPorComprador]
	@empcod smallint,
	@datCadDe datetime,
	@datCadAte datetime,
	@datResDe datetime,
	@datResAte datetime,
	@datAltDe datetime,
	@datAltAte datetime,
	@datPreDe  datetime,
	@datPreAte  datetime,
	@codProduto varchar(8000),
	@desProduto varchar(60),
	@codComprador varchar(500),
	@nomComprador varchar(30),
	@codMarca int,
	@nomMarca varchar(60),
	@codFornecedor int,
	@nomFornecedor varchar(60),
	@numPedCom int,
	@conGrupo int,
	@Status varchar(500)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @DataCad_De datetime, @DataCad_Ate datetime, @DataRes_De datetime, @DataRes_Ate datetime, @DataAlt_De datetime, @DataAlt_Ate datetime, 
			@DataPre_De datetime, @DataPre_Ate datetime, @CodigosProduto varchar(8000), @DescricaoProd varchar(60), @CodigosComprador varchar(500), @NomeComprador varchar(30),
			@MARCOD int, @MARNOM varchar(60), @FORCOD int, @FORNOM varchar(60), @PDCNUM int, @EmpresasGrupo int, @StatusPDC varchar(500),
			@CmdSQL varchar (max), @codigoProdutoNaoCadastrado varchar(8);

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @DataCad_De = (SELECT ISNULL(@datCadDe, '17530101'));
	SET @DataCad_Ate = (SELECT ISNULL(@datCadAte, GETDATE()));
	SET @DataRes_De = (SELECT ISNULL(@datResDe, '17530101'));
	SET @DataRes_Ate = (SELECT ISNULL(@datResAte, GETDATE()));
	SET @DataAlt_De = (SELECT ISNULL(@datAltDe, '17530101'));
	SET @DataAlt_Ate = (SELECT ISNULL(@datAltAte, GETDATE()));
	SET @DataPre_De = (SELECT ISNULL(@datPreDe, '17530101'));
	SET @DataPre_Ate = (SELECT ISNULL(@datPreAte, GETDATE()));
	SET @CodigosProduto = @codProduto;	-- MultiValor
	SET @DescricaoProd = @desProduto;
	SET @CodigosComprador = @codComprador;	-- MultiValor
	SET @NomeComprador = @nomComprador;
	SET @MARCOD = @codMarca;
	SET @MARNOM = @nomMarca;
	SET @FORCOD = @codFornecedor;
	SET @FORNOM = @nomFornecedor;
	SET @PDCNUM = @numPedCom;
	SET @EmpresasGrupo = @conGrupo;
	SET @StatusPDC = @Status;	-- MultiValor
	
	SET @codigoProdutoNaoCadastrado = '99'
	SET @codigoProdutoNaoCadastrado = REPLACE(REPLACE(@codigoProdutoNaoCadastrado,',',''','''),' ','')


	-- Uso da função split, para as claúsulas IN()
	--- Codigos de produto
		If object_id('TempDB.dbo.#CODIGOSPROD') is not null
			DROP TABLE #CODIGOSPROD;
		select elemento as [codpro]
		Into #CODIGOSPROD
		From fSplit(@CodigosProduto, ',')
	--- Codigos de compradores
		If object_id('TempDB.dbo.#CODIGOSCOMP') is not null
			DROP TABLE #CODIGOSCOMP;
		select elemento as [codcom]
		Into #CODIGOSCOMP
		From fSplit(@CodigosComprador, ',')
	--- Status do pedido
		If object_id('TempDB.dbo.#STATUSPED') is not null
			DROP TABLE #STATUSPED;
		select elemento as [statusped]
		Into #STATUSPED
		From fSplit(@StatusPDC, ',')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos compradores

	IF @CodigosComprador <> ''
		SET @CmdSQL = 
			'SELECT COMCOD 
			FROM TBS046 (NOLOCK) 
			WHERE 
			COMCOD IN (SELECT codcom FROM #CODIGOSCOMP)
			UNION 
			SELECT TOP 1 0 FROM TBS046 (NOLOCK) WHERE 0 IN (SELECT codcom FROM #CODIGOSCOMP)
			';
	ELSE
		SET @CmdSQL = 
			'SELECT COMCOD FROM TBS046 (NOLOCK)
			UNION 
			SELECT TOP 1 0 FROM TBS046 (NOLOCK)
			';	

	IF object_id('tempdb.dbo.#COMCOD') is not null
		drop table #COMCOD;

	create table #COMCOD (COMCOD INT)
	
	INSERT INTO #COMCOD
	EXEC(@CmdSQL)

	-- SELECT * FROM #COMCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem detalhes da tabela de compradores
	IF object_id('tempdb.dbo.#Compradores') is not null
		drop table #Compradores;

	SELECT 
	COMCOD,
	LTRIM(RTRIM(STR(COMCOD))) + ' - ' + RTRIM(COMNOM) AS COMNOM

	INTO #Compradores
	FROM TBS046 

	WHERE
	COMCOD IN (SELECT COMCOD FROM #COMCOD) AND 
	RTRIM(LTRIM(COMNOM)) LIKE (CASE WHEN @NomeComprador = '' THEN RTRIM(LTRIM(COMNOM)) ELSE RTRIM(upper(@NomeComprador)) END) 

	UNION

	SELECT
	TOP 1 
	0,
	'0 - SEM COMPRADOR' AS VENNOM

	FROM TBS046 (NOLOCK)

	WHERE
	0 IN (SELECT COMCOD FROM #COMCOD) AND 
	'SEM COMPRADOR' LIKE (CASE WHEN @NomeComprador = '' THEN 'SEM COMPRADOR' ELSE RTRIM(upper(@NomeComprador)) END) 

	-- SELECT * FROM #Compradores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtém códigos dos produtos

	IF @CodigosProduto <> '' 
		SET @CmdSQL = 
			'SELECT rtrim(ltrim(PROCOD)) PROCOD 
			FROM TBS010 (NOLOCK) 
			WHERE 
			PROCOD IN (SELECT codpro from #CODIGOSPROD) 			
			UNION
			SELECT distinct rtrim(ltrim(CBPPROCOD)) PROCOD 
			FROM TBS0103 (NOLOCK) 
			WHERE 
			CBPCODBAR IN (SELECT codpro from #CODIGOSPROD)
			UNION 
			SELECT TOP 1 ''99'' 
			FROM TBS010 (nolock)						
			WHERE 
			''99'' IN (SELECT codpro from #CODIGOSPROD)';
	ELSE
		SET @CmdSQL = 
			'SELECT RTRIM(PROCOD) PROCOD FROM TBS010 (NOLOCK)';

	if object_id('tempdb.dbo.#PROCOD') is not null
		drop table #PROCOD;

	create table #PROCOD (PROCOD CHAR(15))
	INSERT INTO #PROCOD
	EXEC(@CmdSQL)

	-- SELECT * FROM #PROCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Detalhes dos produtos

	IF OBJECT_ID ('tempdb.dbo.#TBS010') is not null
		drop table #TBS010;

	SELECT  
	PROCOD

	INTO #TBS010
	FROM TBS010 A (NOLOCK)

	WHERE 
	A.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #PROCOD) AND 
	A.MARNOM LIKE(CASE WHEN @MARNOM = '' THEN A.MARNOM ELSE UPPER(RTRIM(@MARNOM)) END) AND
	A.MARCOD = (CASE WHEN @MARCOD = 0 THEN A.MARCOD ELSE @MARCOD END)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Incluir codigo do produto não cadastrado, caso seja filtrado 
 
	IF (select count(*) from #PROCOD where PROCOD in (''+@codigoProdutoNaoCadastrado+'')) > 0	
		insert into #TBS010
		select '99'	;
		-- caso for incluir mais, acrescenta com o union, e faz o select no outro codigo que foi acrescentado.		

	-- select * from #TBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- CONTABILIZA FORNECEDORES DO GRUPO? NÃO	
	-- Dica: Mudar a forma de veriricar, invertendo a lógica, pois atualmente 1 = NÃO; ~00~
	IF @EmpresasGrupo = 1 
		SET @CmdSQL = 
			'SELECT TOP 1 -1, '''' FROM TBS006 (nolock)';
	ELSE 
	BEGIN
		IF object_id('tempdb.dbo.#CodigosFornecedorGrupo') is not null	
			drop table #CodigosFornecedorGrupo;

		create table #CodigosFornecedorGrupo (codigo int);

		insert into #CodigosFornecedorGrupo
		exec usp_FornecedoresGrupo @codigoEmpresa;

		SET @CmdSQL = 
			'SELECT FORCOD, RTRIM(FORNOM) AS FORNOM FROM TBS006 (nolock) 
			WHERE 
			FORCOD in (select codigo from #CodigosFornecedorGrupo) and
			FORCOD = CASE WHEN '+STR(@FORCOD)+' = 0 THEN FORCOD ELSE '+STR(@FORCOD)+' END AND 
			FORNOM LIKE(CASE WHEN '''+@FORNOM+''' = '''' THEN FORNOM ELSE '''+RTRIM(UPPER(@FORNOM))+''' END)';
	END
	
	IF object_id('tempdb.dbo.#TBS006GRU') is not null
		drop table #TBS006GRU;

	CREATE TABLE #TBS006GRU (FORCOD INT, FORNOM VARCHAR(60))
	INSERT INTO #TBS006GRU
	EXEC(@CmdSQL)

	-- SELECT * FROM #TBS006GRU
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- FORNECEDORES SEM O GRUPO SEMPRE VAI EXISTIR 

	IF object_id('tempdb.dbo.#TBS0061') is not null
		drop table #TBS0061;
	
	SELECT 
	FORCOD, 
	RTRIM(FORNOM) AS FORNOM
	
	INTO #TBS0061 
	FROM TBS006 (nolock) 

	WHERE 
	FORCOD NOT IN (select codigo from #CodigosFornecedorGrupo) AND 
	FORCOD = CASE WHEN @FORCOD = 0 THEN FORCOD ELSE @FORCOD END AND 
	FORNOM LIKE (CASE WHEN @FORNOM = '' THEN FORNOM ELSE rtrim(ltrim(upper(@FORNOM))) END)		

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela unica de fornecedores, com ou sem empresas do grupo BMPT

	IF object_id('tempdb.dbo.#Fornecedores') is not null
		drop table #Fornecedores;

	SELECT 
	FORCOD, 
	FORNOM COLLATE DATABASE_DEFAULT AS FORNOM 
	INTO #Fornecedores 
	FROM #TBS0061

	UNION 
	SELECT 
	FORCOD, 
	FORNOM 
	FROM #TBS006GRU

	-- SELECT * FROM #Fornecedores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Unir as tabelas para formar uma tabela final, com preço unitario final de cada item

	IF object_id('tempdb.dbo.#PedidoCompras1') is not null
		drop table #PedidoCompras1;

	SELECT 
	B.PDCBLQ				AS Bloqueado,
	A.PDCITE				AS ItemPedido,
	B.COMCOD				AS CodigoComprador,
	C.COMNOM				AS CodigoNomeComprador,
	A.PDCNUM				AS NumeroPedido,
	B.FORCOD				AS CodigoFornecedor,
	D.FORNOM				AS NomeFornecedor,
	PDCDATCAD				AS DataCadastro,
	B.PDCHORCAD				AS HoraCadastro,
	RTRIM(PDCUSUCAD)		AS UsuarioCadastrou,
	PDCDATRES				AS DataEliminacaoResiduo,
	B.PDCHORRES				AS HoraEliminacaoResiduo,
	RTRIM(PDCUSURES)		AS UsuarioEliminouResiduo,
	PDCDATALT				AS DataAlteracao,
	B.PDCHORALT				AS HoraAlteracao,
	RTRIM(PDCUSUALT)		AS UsuarioAlterou,
	RTRIM(PROCOD)			AS CodigoProduto,
	RTRIM(PDCDES)			AS DescricaoProduto,
	RTRIM(PDCUNI)+''+ CASE WHEN PDCQTDEMB > 1 THEN +' c/'+ RTRIM(CONVERT(DECIMAL,PDCQTDEMB,0)) ELSE '' END AS UnidadeMedidaComprada,
	A.PDCQTD				AS QuantidadeTotal,
	A.PDCQTDENT				AS QuantidadeEntrada,
	A.PDCQTDRES				AS QuantidadeResiduo,
	CASE WHEN (PDCQTD - PDCQTDENT - PDCQTDRES ) > 0 THEN PDCQTD ELSE 0 END AS QuantidadeAberto,
	PDCPRE - (PDCPRE*PDCPDDITE/100) + (PDCPRE*PDCPORFREITE/100) + (PDCPRE*PDCPORSEGITE/100) + (PDCPRE*PDCPOROUTITE/10) + (PDCPRE*PDCIPI/100) + ((PDCPRE + (PDCPRE*PDCIPI/100))*PDCPORST/100) AS PrecoUnitario,
	B.PDCDATPEN				AS PrevisaoEntrega,
	RTRIM(PDCOBS)			AS Observacao,
	B.PDCCPGCOD				AS CodigoCondicaoPagamento,
	RTRIM(LTRIM(isnull(E.CPGDES,'')))	AS DescricaoPagamento,
	B.PDCDATPFA				AS DataPrevistaFaturamento

	into #PedidoCompras1
	FROM TBS045 B (NOLOCK)
	INNER JOIN TBS0451 A (NOLOCK) ON A.PDCNUM = B.PDCNUM
	LEFT JOIN #Compradores C ON B.COMCOD = C.COMCOD
	LEFT JOIN #Fornecedores D ON B.FORCOD = D.FORCOD 
	LEFT JOIN TBS008 E (NOLOCK) ON B.PDCCPGCOD = E.CPGCOD

	WHERE 
	PDCDATCAD BETWEEN @DataCad_De AND @DataCad_Ate
	AND PDCDATRES BETWEEN @DataRes_De AND @DataRes_Ate
	AND PDCDATALT BETWEEN @DataAlt_De AND @DataAlt_Ate
	AND B.COMCOD IN ( SELECT COMCOD FROM #Compradores)
	AND A.PROCOD IN ( SELECT PROCOD FROM #TBS010)
	AND PDCDES LIKE (CASE WHEN @DescricaoProd = '' THEN PDCDES ELSE RTRIM(UPPER(@DescricaoProd)) END)
	AND B.FORCOD IN (SELECT FORCOD FROM #Fornecedores)
	AND A.PDCNUM in (CASE WHEN @PDCNUM = 0 THEN A.PDCNUM ELSE @PDCNUM END)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela para idetificar o status do pedido

	IF object_id('tempdb.dbo.#PedidoCompras') is not null
		drop table #PedidoCompras;

	select 
	case when SUM(QuantidadeAberto) OVER (PARTITION BY NumeroPedido) > 0 and SUM(QuantidadeEntrada) OVER (PARTITION BY NumeroPedido) = 0 
		then 'Aberto'
		else
			case when SUM(QuantidadeResiduo) OVER (PARTITION BY NumeroPedido) = SUM(QuantidadeTotal) OVER (PARTITION BY NumeroPedido)
				then 'Eliminado'
				else 
					case when SUM(QuantidadeEntrada) OVER (PARTITION BY NumeroPedido) = SUM(QuantidadeTotal) OVER (PARTITION BY NumeroPedido)
						then 'Atendido'
						else 
							case when SUM(QuantidadeEntrada) OVER (PARTITION BY NumeroPedido) > 0 and SUM(QuantidadeResiduo) OVER (PARTITION BY NumeroPedido) > 0 and SUM(QuantidadeAberto) OVER (PARTITION BY NumeroPedido) = 0
								then 'Atendido/Eliminado'
								else
									case when SUM(QuantidadeAberto) OVER (PARTITION BY NumeroPedido) > 0 and SUM(QuantidadeEntrada) OVER (PARTITION BY NumeroPedido) > 0
										then 'Parcial'
										else 'Nao Identificado'
									end
							end
					end
			end
	end as Status,
	*,
	round(PrecoUnitario * QuantidadeTotal,2) as ValorTotal,
	round(PrecoUnitario * QuantidadeEntrada,2) as ValorEntrada,
	round(PrecoUnitario * QuantidadeResiduo,2) as ValorResiduo,
	round(PrecoUnitario * QuantidadeAberto,2) as ValorAberto

	into #PedidoCompras
	from #PedidoCompras1  

	where 
	PrevisaoEntrega BETWEEN @DataPre_De AND @DataPre_Ate

	order by 
	NumeroPedido,
	ItemPedido
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	select 
	* 	
	from #PedidoCompras 
	where Status in (SELECT statusped FROM #STATUSPED) 
	order by CodigoComprador, NumeroPedido, ItemPedido
END