/*
====================================================================================================================================================================================
WREL151 - Pedidos de Compras x Notas Entrada
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
15/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_PedidosComprasxNotasEntrada]
--ALTER PROCEDURE [dbo].[usp_RS_PedidosComprasxNotasEntrada]
	@empcod smallint,
	@datCadDe datetime,
	@datCadAte datetime,
	@datResDe datetime,
	@datResAte datetime,
	@datAltDe datetime,
	@datAltAte datetime,
	@datPreDe datetime,
	@datPreAte datetime,
    @codProduto varchar(500),
	@desProduto varchar(60),
	@codComprador varchar(500),
	@nomComprador varchar(60),
	@codMarca int,
	@nomMarca varchar(60),
	@codFornecedor int,
	@nomFornecedor varchar(60),
	@numPedCom int,
	@conGrupo char(1),
	@Status varchar(500)	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint,
			@DatCad_De datetime, @DatCad_Ate datetime, 	@DatRes_De datetime, @DatRes_Ate datetime, @DatAlt_De datetime, @DatAlt_Ate datetime, @DatPre_De datetime, @DatPre_Ate datetime,
			@CodigosProduto varchar(500), @PRODES varchar(60), @CodigosComprador varchar(500), @COMNOM varchar(60), @MARCOD int, @MARNOM varchar(60), @FORCOD int, @FORNOM varchar(60),
			@PDCNUM int, @IncForGrupo char(1), @StatusPed varchar(500),
			@codigoProdutoNaoCadastrado varchar(15), @cmdSQL varchar (max);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @DatCad_De = (SELECT ISNULL(@datCadDe, '17530101'));
	SET @DatCad_Ate = (SELECT ISNULL(@datCadAte, GETDATE()));
	SET	@DatRes_De = (SELECT ISNULL(@datResDe, '17530101'));
	SET @DatRes_Ate = (SELECT ISNULL(@datResAte, GETDATE())); 
	SET @DatAlt_De = (SELECT ISNULL(@datAltDe, '17530101'));
	SET @DatAlt_Ate = (SELECT ISNULL(@datAltAte, GETDATE())); 
	SET @DatPre_De = (SELECT ISNULL(@datPreDe, '17530101'));
	SET @DatPre_Ate = (SELECT ISNULL(@datPreAte, (SELECT MAX(PDCDATPEN) FROM TBS045 (NOLOCK)))); 
	SET @CodigosProduto = RTRIM(LTRIM(@codProduto));
	SET @PRODES = RTRIM(LTRIM(UPPER(@desProduto)));
	SET @CodigosComprador = @codComprador;
	SET @COMNOM = RTRIM(LTRIM(UPPER(@nomComprador)));
	SET @MARCOD = @codMarca;
	SET @MARNOM = RTRIM(LTRIM(UPPER(@nomMarca)));	
	SET @FORCOD = @codFornecedor;
	SET @FORNOM = RTRIM(LTRIM(UPPER(@nomFornecedor)));	
	SET @PDCNUM = @numPedCom;
	SET @IncForGrupo = @conGrupo;
	SET @StatusPed = @Status;

	-- Produto 99 definido como não cadastrado em pedido de compras	
	SET @codigoProdutoNaoCadastrado = '99'
	
-- Uso da funcao split, para as clausulas IN()
	-- Codigos dos compradores
	IF object_id('TempDB.dbo.#CodigosComprador') IS NOT NULL
		DROP TABLE #CodigosComprador;
	SELECT 
		elemento as valor
	INTO #CodigosComprador FROM fSplit(@CodigosComprador, ',');
	-- Status dos pedidos
	IF object_id('TempDB.dbo.#StatusPed') IS NOT NULL
		DROP TABLE #StatusPed;
	SELECT 
		elemento as valor
	INTO #StatusPed FROM fSplit(@StatusPed, ',');
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos produtos conforme filtro utilizando a SP

	IF object_id('tempdb.dbo.#CodigosProduto') IS NOT NULL
		DROP TABLE #CodigosProduto;	
	
	CREATE TABLE #CodigosProduto (PROCOD varchar(15))

	INSERT INTO #CodigosProduto
	EXEC usp_GetCodigosProdutos @codigoEmpresa, @CodigosProduto, @PRODES, @MARCOD, @MARNOM

--	select * from #CodigosProduto

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos compradores

	IF @CodigosComprador <> '' 
		SET @cmdSQL = 'SELECT COMCOD 
						FROM TBS046 (NOLOCK) 
						WHERE 
						COMCOD IN (SELECT valor FROM #CodigosComprador)
						UNION 
						SELECT TOP 1 0 FROM TBS046 (NOLOCK) WHERE 0 IN (SELECT valor FROM #CodigosComprador)';	
	ELSE
		SET @cmdSQL	= 'SELECT COMCOD FROM TBS046 (NOLOCK)
					   UNION 
						SELECT TOP 1 0 FROM TBS046 (NOLOCK)';	

	-- PRINT @cmdSQL

	IF object_id('tempdb.dbo.#COMCOD') is not null
		drop table #COMCOD;

	CREATE TABLE #COMCOD (COMCOD INT)
	
	INSERT INTO #COMCOD
	EXEC(@cmdSQL)

	-- SELECT * FROM #COMCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos compradores 

	IF object_id('tempdb.dbo.#Compradores') IS NOT NULL
		DROP TABLE #Compradores;

	SELECT 
		COMCOD,
		LTRIM(RTRIM(STR(COMCOD))) + ' - ' + RTRIM(COMNOM) AS COMNOM
	INTO #Compradores FROM TBS046 
	WHERE
		COMCOD IN (SELECT COMCOD FROM #COMCOD) AND 
		RTRIM(LTRIM(COMNOM)) LIKE (CASE WHEN @COMNOM = '' THEN RTRIM(LTRIM(COMNOM)) ELSE @COMNOM END) 

	UNION

	SELECT TOP 1 
		0,
		'0 - SEM COMPRADOR' AS VENNOM
	FROM TBS046 (NOLOCK)
	WHERE
		0 IN (SELECT COMCOD FROM #COMCOD) AND 
		'SEM COMPRADOR' LIKE (CASE WHEN @COMNOM = '' THEN 'SEM COMPRADOR' ELSE @COMNOM END) 

	-- SELECT * FROM #Compradores

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA BASE 
	-- FORNECEDORES
	-- CONTABILIZA FORNECEDORES DO GRUPO? NÃO

	IF object_id('tempdb.dbo.#CodigosFornecedorGrupo') IS NOT NULL
		DROP TABLE #CodigosFornecedorGrupo;		

	CREATE TABLE #CodigosFornecedorGrupo (codigo int)
	
	INSERT INTO #CodigosFornecedorGrupo
	EXEC usp_FornecedoresGrupo @codigoempresa;

	IF @IncForGrupo <> 'S'
		SET @cmdSQL = 'SELECT TOP 1 -1, '''' FROM TBS006 (nolock)';	
	ELSE	
		SET @cmdSQL = 'SELECT FORCOD, RTRIM(FORNOM) AS FORNOM FROM TBS006 (nolock) 
					WHERE 
					FORCOD in (select codigo from #CodigosFornecedorGrupo) and
					FORCOD = CASE WHEN '+STR(@FORCOD)+' = 0 THEN FORCOD ELSE '+STR(@FORCOD)+' END AND 
					FORNOM LIKE(CASE WHEN '''+@FORNOM+''' = '''' THEN FORNOM ELSE '''+ @FORNOM + ''' END)';

	IF object_id('tempdb.dbo.#TBS006GRU') IS NOT NULL	
		DROP TABLE #TBS006GRU;

	CREATE TABLE #TBS006GRU (FORCOD INT, FORNOM VARCHAR(60))
	INSERT INTO #TBS006GRU
	EXEC(@cmdSQL)

	-- SELECT * FROM #TBS006GRU

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- FORNECEDORES SEM O GRUPO SEMPRE VAI EXISTIR 

	IF object_id('tempdb.dbo.#TBS0061') IS NOT NULL	
		DROP TABLE #TBS0061;
		
	SELECT 
		FORCOD, 
		RTRIM(FORNOM) AS FORNOM 
	INTO #TBS0061 FROM TBS006 (nolock) 
	WHERE 
		FORNOM LIKE(CASE WHEN @FORNOM = '' THEN FORNOM ELSE @FORNOM END) AND 
		FORCOD = (CASE WHEN @FORCOD = 0 THEN FORCOD ELSE @FORCOD END) AND
		FORCOD NOT IN (select codigo from #CodigosFornecedorGrupo)

	-- SELECT * FROM #TBS0061

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DOS FORNECEDORES
	IF object_id('tempdb.dbo.#Fornecedores') is not null
		DROP TABLE #Fornecedores;

	SELECT 
		FORCOD, 
		FORNOM COLLATE DATABASE_DEFAULT AS FORNOM		
	INTO #Fornecedores FROM #TBS0061

	UNION 
	SELECT 
		FORCOD, 
		FORNOM 
	FROM #TBS006GRU

	-- SELECT * FROM #Fornecedores

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Unir as tabelas para formar uma tabela final, com preço unitario final de cada item

	IF object_id('tempdb.dbo.#PedidoCompras1') IS NOT NULL
		DROP TABLE #PedidoCompras1;

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
		A.PDCQTD 				AS QuantidadeTotal,
		A.PDCQTDENT 			AS QuantidadeEntrada,
		A.PDCQTDRES				AS QuantidadeResiduo,
		CASE WHEN (PDCQTD - PDCQTDENT - PDCQTDRES ) > 0 THEN PDCQTD - PDCQTDENT - PDCQTDRES ELSE 0 END AS QuantidadeAberto,
		PDCPRE - (PDCPRE*PDCPDDITE/100) + (PDCPRE*PDCPORFREITE/100) + (PDCPRE*PDCPORSEGITE/100) + (PDCPRE*PDCPOROUTITE/10) + (PDCPRE*PDCIPI/100) + ((PDCPRE + (PDCPRE*PDCIPI/100))*PDCPORST/100) AS PrecoUnitario,
		B.PDCDATPEN				AS PrevisaoEntrega,
		RTRIM(PDCOBS)			AS Observacao,
		B.PDCCPGCOD				AS CodigoCondicaoPagamento,
		RTRIM(LTRIM(isnull(E.CPGDES,'')))	AS DescricaoPagamento,
		B.PDCDATPFA				AS DataPrevistaFaturamento
	INTO #PedidoCompras1 FROM TBS045 B (NOLOCK)
		INNER JOIN TBS0451 A (NOLOCK) ON A.PDCNUM = B.PDCNUM
		LEFT JOIN #Compradores C ON B.COMCOD = C.COMCOD
		LEFT JOIN #Fornecedores D ON B.FORCOD = D.FORCOD 
		LEFT JOIN TBS008 E (NOLOCK) ON B.PDCCPGCOD = E.CPGCOD
	WHERE 
		PDCDATCAD BETWEEN @DatCad_De AND @DatCad_Ate AND
		PDCDATRES BETWEEN @DatRes_De AND @DatRes_Ate AND
		PDCDATALT BETWEEN @DatAlt_De AND @DatAlt_Ate AND
		B.COMCOD IN ( SELECT COMCOD FROM #Compradores) AND 
		A.PROCOD COLLATE DATABASE_DEFAULT IN ( SELECT PROCOD FROM #CodigosProduto) AND 	
		B.FORCOD IN (SELECT FORCOD FROM #Fornecedores) AND
		A.PDCNUM in (CASE WHEN @PDCNUM = 0 THEN A.PDCNUM ELSE @PDCNUM END)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela para idetificar o status do pedido

	IF object_id('tempdb.dbo.#PedidoCompras2') IS NOT NULL
		DROP TABLE #PedidoCompras2;

	SELECT 
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

	INTO #PedidoCompras2 FROM #PedidoCompras1  
	WHERE
		PrevisaoEntrega BETWEEN @DatPre_De  AND @DatPre_Ate

	ORDER BY 
		NumeroPedido,
		ItemPedido

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos pedidos de compras

	IF object_id('tempdb.dbo.#PedidoCompras') IS NOT NULL	
		DROP TABLE #PedidoCompras;

	SELECT 
		* 
	INTO #PedidoCompras FROM #PedidoCompras2
	WHERE
		Status IN (SELECT valor FROM #StatusPed) 
	ORDER BY
		CodigoComprador,
		NumeroPedido,
		ItemPedido

	-- select * from #PedidoCompras

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Notas de entrada dos pedidos de comrpas filtrados 

	IF object_id('tempdb.dbo.#NotasEntrada') IS NOT NULL
		DROP TABLE #NotasEntrada;	

	SELECT
		 a.NFENUM as numeroNota,
		 a.NFECOD as codigoFornecedor,
		 a.NFEPEDNUM as numeroPedido,
		 a.NFEPEDITE as itemPedido,
		 max(c.NFEDATEFE) as dataEfetivacao,
		 rtrim(b.PROCOD) as codigoProduto,
		 sum(a.NFEATEQTD) as quantidadeEntrada
	INTO #NotasEntrada FROM TBS0592 a (nolock)
		INNER JOIN  TBS0591 b (nolock) on 
		a.NFEEMPCOD = b.NFEEMPCOD and 
		a.NFETIP = b.NFETIP and 
		a.NFENUM = b.NFENUM and 
		a.NFECOD = b.NFECOD and
		a.SEREMPCOD = b.SEREMPCOD and
		a.SERCOD = b.SERCOD and 
		a.NFEITE = b.NFEITE
		INNER JOIN TBS059 c (nolock) on
		a.NFEEMPCOD = c.NFEEMPCOD and 
		a.NFETIP = c.NFETIP and
		a.NFENUM = c.NFENUM and
		a.NFECOD = c.NFECOD and
		a.SEREMPCOD = c.SEREMPCOD and
		a.SERCOD = c.SERCOD
	WHERE
		a.NFETIPPED = 'C' and 
		a.NFEPEDNUM	in (select distinct NumeroPedido from #PedidoCompras) and 
		a.NFEATEQTD <> 0 and 
		c.NFECAN <> 'S'
	GROUP BY
		a.NFETIPPED,
		a.NFENUM,
		a.NFECOD,
		a.NFEPEDNUM,
		a.NFEPEDITE,
		rtrim(b.PROCOD)
	ORDER BY 
		a.NFETIPPED, 
		a.NFEPEDNUM

	-- select * from TBS0592 (nolock) where NFETIPPED = 'C' and NFENUM = 3386

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cruzamento dos pedidos com as notas de entrada

	IF object_id('tempdb.dbo.#PedidoComprasNotasEntrada') IS NOT NULL
		DROP TABLE #PedidoComprasNotasEntrada;
		
	SELECT 
		a.*,
		row_number() over(partition by a.CodigoFornecedor, a.NumeroPedido, a.ItemPedido order by isnull(b.dataEfetivacao, '17530101')) as rankAtendimento,
		isnull(b.numeroNota, 0) as numeroNota,
		isnull(b.quantidadeEntrada, 0) as quantidadeEntradaNota
	INTO #PedidoComprasNotasEntrada FROM #PedidoCompras a (NOLOCK)
		LEFT JOIN #NotasEntrada b (nolock) ON
		a.NumeroPedido = b.numeroPedido and 
		a.CodigoFornecedor = b.codigoFornecedor and 
		a.ItemPedido = b.itemPedido and 
		a.CodigoProduto = b.codigoProduto	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Zerar linha que 'duplica o item' por causa de notas diferentes, isso servirá para o reports, quando fazer o somatorio dos valores 

	BEGIN TRAN 
		UPDATE #PedidoComprasNotasEntrada SET
			QuantidadeTotal = 0, 
			QuantidadeEntrada = 0, 
			QuantidadeResiduo = 0, 
			QuantidadeAberto = 0, 
			ValorTotal = 0, 
			ValorEntrada = 0, 
			ValorResiduo = 0, 
			ValorAberto = 0	
		WHERE
			rankAtendimento > 1
	COMMIT TRAN 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		*, 
		case when rankAtendimento = 1 then 1 else 0 end as qtdItens
	FROM #PedidoComprasNotasEntrada
/**/
END