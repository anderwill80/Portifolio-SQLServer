/*
====================================================================================================================================================================================
															Script do Report Server
====================================================================================================================================================================================
											Pendências de vendas do grupo por nota fiscal de entrada
====================================================================================================================================================================================
														Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
10/05/2024	ANDERSON WILLIAM			- Criação, permite mostras as pendências de vendas dos itens contido na nota fiscal de entrada

************************************************************************************************************************************************************************************
*/
create proc [dbo].[usp_RS_PendenciasVendasporNota](
--alter proc [dbo].[usp_RS_PendenciasVendasporNota](
	@empcod int,
	@chaveAcesso char(44),
	@numeroNF decimal(10,0),
	@serieNF char(3),
	@codigoFor int,
	@empresas varchar(100),
	@tipoPendencia varchar(20)
	)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais

	declare @codigoempresa smallint, @NFECHAACE varchar(44), @NFENUM decimal(10,0), @NFESERDOC char(3), @NFECOD int, @EmpresasPen varchar(100), @tipPendencia varchar(20),
			@empresaTBS059 int,
			@verificaLink int, @serverIPRemoto varchar(15), @count int, @countEmp int, @empresa varchar(2), @empresaNome varchar(13), @bancoNome varchar(6),
			@Query nvarchar (MAX), @ParmDef nvarchar (500)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições para desabilitar o "Parameter Sniffing" do SQL

	SET @codigoempresa = @empcod
	SET @NFECHAACE = @chaveAcesso
	SET @NFENUM = @numeroNF
	SET @NFESERDOC = @serieNF
	SET @NFECOD = @codigoFor
	SET @EmpresasPen = @empresas			-- Empresas: TANBYS(TM;TT;TD);PY;MI;BB;WP
	SET @tipPendencia = @tipoPendencia		-- Tipo de pendência: PDV(Pedido de vendas);SDC(Solicitação de compras)
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Função split para obter os valores dos parâmetros mult-valores

	If object_id('TempDB.dbo.#EMPRESASPEN') is not null
		DROP TABLE #EMPRESASPEN

    select elemento as [emp]
	Into #EMPRESASPEN
    From fSplit(@EmpresasPen, ',')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")

	exec dbo.usp_GetCodigoEmpresaTabela @codigoempresa, 'TBS059', @empresaTBS059 output;		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria tabela geral de pendências, que irá conter as pendências de todas as empresas do grupo, conforme o itens da nota de entrada

	If object_id('TempDB.dbo.#pengeral') is not null
	   drop table #pengeral

	CREATE TABLE #pengeral( 
		PENEMP CHAR (13) NOT NULL, 			-- EMPRESA				
		PENTIP CHAR (3) NOT NULL, 			-- SE É UM PDV OU SDC
		PENNUM INT NOT NULL, 				-- NUMERO DO PEDIDO 
		PENITE INT NOT NULL,				-- NUMERO DO ITEM DO PEDIDO 
		PENVENNOM CHAR(40) 	,				-- NOME VENDEDOR/SOLICITANTE 
		PENCLICOD INT NOT NULL , 			-- CODIGO DO CLIENTE
		PENCLINOM VARCHAR(60),	 			-- NOME DO CLIENTE
		PENCOD CHAR (15) NOT NULL,			-- CODIGO DO PRODUTO
		PENQTDITE DECIMAL (12, 6) NOT NULL,	-- QTD DO ITEM PENDENTE
		PENVALITE MONEY NOT NULL,			-- VALOR DO ITEM PENDENTE
		PENDAT DATETIME NOT NULL,			-- DATA DA PENDENCIA
		PENDIA INT NOT NULL,				-- DIAS NA PENDENCIA
		ESTLOC INT NOT NULL,				-- LOCAL DO ESTOQUE
		PENCMP DECIMAL(12, 6),
		PENDIS DECIMAL(12, 6),
		PENDISLOJ DECIMAL(12, 6),
		PENDISEST DECIMAL(12, 6)
		)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtém os itens da nota fiscal de entrada
	If object_id('TempDB.dbo.#ItensNF') is not null
	   drop table #ItensNF

	-- Select TOP 0  para criar a estrutura da tabela igual a original
	SELECT TOP 0
	A.NFENUM,
	A.NFESERDOC,
	A.NFECOD,
	NFENOM,
	NFEDATEMI,
	NFEITE,
	PROCOD,
	NFEDES,
	NFEUNI,
	NFEQTD,
	LESCOD

	INTO #ItensNF

	FROM TBS059 (NOLOCK) AS A
	JOIN TBS0591 (NOLOCK) AS B ON B.NFEEMPCOD = A.NFEEMPCOD AND B.NFECOD = A.NFECOD AND B.NFENUM = A.NFENUM AND B.SERCOD = A.SERCOD	

	SET @Query	= N'
	INSERT INTO #ItensNF

	SELECT 
	A.NFENUM,
	A.NFESERDOC,
	A.NFECOD,
	NFENOM,
	NFEDATEMI,
	NFEITE,
	PROCOD,
	NFEDES,
	NFEUNI,
	NFEQTD,
	LESCOD

	FROM TBS059 (NOLOCK) AS A
	JOIN TBS0591 (NOLOCK) AS B ON B.NFEEMPCOD = A.NFEEMPCOD AND B.NFECOD = A.NFECOD AND B.NFENUM = A.NFENUM AND B.SERCOD = A.SERCOD

	WHERE 
	A.NFEEMPCOD = @empresaTBS059 AND
	NFECAN <> ''S''
	'		
	+
	IIf(@NFECHAACE = '' OR LEN(@NFECHAACE) < 44, '', ' AND NFECHAACE = @NFECHAACE')

	-- Se usuário não usou a chave, e sim o numero da nota/serie e fornecedor
	If (@NFECHAACE = '' OR LEN(@NFECHAACE) < 44)
	Begin
		SET @Query += ' AND A.NFENUM = @NFENUM AND NFESERDOC = @NFESERDOC AND A.NFECOD = @NFECOD
					  ORDER BY A.NFEEMPCOD, A.NFECOD, A.NFENUM, NFESERDOC'
	End
	Else
	Begin
		SET @Query += ' ORDER BY A.NFEEMPCOD, NFECHAACE'
	End

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS059 int, @NFECHAACE varchar(44), @NFENUM decimal(10,0), @NFESERDOC char(3), @NFECOD int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS059, @NFECHAACE, @NFENUM, @NFESERDOC, @NFECOD	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtém os códigos de produtos distintos da nota, para buscar as pendências

	If object_id('TempDB.dbo.#ProdutosNF') is not null
	   drop table #ProdutosNF

	SELECT 
	NFENUM, 
	NFESERDOC,
	NFECOD,
	NFENOM,
	NFEDATEMI,
	PROCOD,	
	SUM(NFEQTD) AS QTDENT

	INTO #ProdutosNF

	FROM #ItensNF
	GROUP BY NFENUM, NFESERDOC,	NFECOD, NFENOM,	NFEDATEMI, PROCOD
/*
	SELECT * FROM #ItensNF
	SELECT * FROM #ProdutosNF
*/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obter as pendências das outras empresas do grupo, conforme as empresas selecionados pelo usuário,
	-- nos parâmetros do ReportServer
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		

	-- Obtém a quantidade de empresas selecionadas
	SET @countEmp = (SELECT COUNT(*) FROM #EMPRESASPEN)

	SET @count = 0

	WHILE @count < @countEmp
	BEGIN

		-- Navega na tabela com as empresas escolhidas pelo usuário, para obter a sigla
		SET @empresa = (
			SELECT emp FROM  #EMPRESASPEN 	
			order by emp
			OFFSET @count ROWS 
			FETCH NEXT 1 ROWS ONLY)

		-- A varivel @empresa contem o nome dos linkedservers: nd,tt,cd,bb,py,mi,wp, que será usada para obter o IP remoto
		SET @serverIPRemoto = (select top 1 data_source from sys.servers where name = @empresa order by name)

		exec VerificaLink3 @serverIPRemoto, @verificaLink output	
	
		If @verificaLink <> 1
			PRINT @serverIPRemoto + ' = OFFLINE'
		Else
		Begin
			-- Obtém nome da empresa que será gravada na coluna 'PENEMP'
			SET @empresaNome = 
				CASE @empresa
					WHEN 'nd' THEN 'Tanby Matriz'
        			WHEN 'tt' THEN 'Tanby Taubate'
					WHEN 'cd' THEN 'Tanby CD'
					WHEN 'py' THEN 'Papelyna'
					WHEN 'mi' THEN 'Misaspel'
					WHEN 'bb' THEN 'BestBag'
					WHEN 'wp' THEN 'WinPack'    
				END

			-- Obtém nome do banco de dados conforme o nome do servidor vinculado(linked server)
			SET @bancoNome = 
				CASE 
					WHEN @empresa IN('nd', 'tt', 'cd', 'py')  THEN 'SIBD'        			
					WHEN @empresa = 'bb' THEN 'SIBD2'
					WHEN @empresa = 'mi' THEN 'SIBD3'					
					WHEN @empresa = 'wp' THEN 'SIBD4'
				END

			If CHARINDEX('PDV', @tipPendencia) > 0
			Begin
				SET @Query = '		
				SELECT
				''' + @empresaNome + ''' as LOCAL,
				''PDV'' collate Latin1_General_BIN AS PDV,
				PRPNUM AS PED , 
				PRPITEM,
				ISNULL(VENNOM, ''SEM VENDEDOR'') collate Latin1_General_BIN  AS VEN,
				PRPCLICOD AS CLICOD,
				CLINOM,
				PROCOD collate Latin1_General_BIN AS COD,
				(PRPQTD * PRPQTDEMB) AS QTD ,
				(PRPPRELIQ / PRPQTDEMB) * (PRPQTD * PRPQTDEMB) as VAL,
				PRPDATREG AS DATCAD ,
				DATEDIFF(DAY, PRPDATREG, getdate()) AS DIAS_PEN,
				PRPESTLOC AS ESTLOC,
				COMPRAS,
				DISPONIVEL,
				EST,
				LOJA		
	
				FROM OPENROWSET(''SQLNCLI'', ''' + @serverIPRemoto + ''';''integros'';''int3gro5@15387'', ''

				SELECT
				PRPNUM,
				PRPITEM,
				C.VENNOM AS VENNOM, 
				PRPCLICOD, 
				CLINOM,
				A.PROCOD AS PROCOD,
				PRPQTD,
				PRPQTDEMB,
				PRPPRELIQ,
				PRPDATREG, 
				PRPESTLOC, 
				ISNULL((SELECT SUM(ESTQTDCMP) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE A.PROCOD = J.PROCOD AND ESTLOC IN(1,2) GROUP BY PROCOD), 0) AS COMPRAS,
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE A.PROCOD = J.PROCOD AND ESTLOC IN(1,2) GROUP BY PROCOD), 0) AS DISPONIVEL,
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE A.PROCOD = J.PROCOD AND ESTLOC IN(1) GROUP BY PROCOD), 0) AS EST,
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE A.PROCOD = J.PROCOD AND ESTLOC IN(2) GROUP BY PROCOD), 0) AS LOJA

				FROM ' + @bancoNome + '.dbo.TBS058 A (NOLOCK)
				LEFT JOIN ' + @bancoNome + '.dbo.TBS004 C (NOLOCK) ON A.PRPVENCOD = C.VENCOD
				LEFT JOIN ' + @bancoNome + '.dbo.TBS002 D (NOLOCK) ON CLICOD = PRPCLICOD

				WHERE
				PRPSIT = ''''P'''' AND 
				PRPMOVEST = ''''S''''
				'') AS Ped
				Where Ped.PROCOD collate Latin1_General_BIN IN(SELECT PROCOD FROM #ProdutosNF)'

				-- Executa a query acima que irá incluir registros na #pengeral
				INSERT INTO #pengeral
				exec(@Query)				
			End

			If CHARINDEX('SDC', @tipPendencia) > 0
			Begin			
				SET @Query = '		
				SELECT
				''' + @empresaNome + ''' as LOCAL,
				''SDC'' collate Latin1_General_BIN AS SDC,
				SDCNUM AS PED, 
				SDCITE,
				ISNULL(CCSNOM, ''SEM VENDEDOR'') collate Latin1_General_BIN  AS VEN,
				0 AS CLICOD,	
				''SEM CLIENTE'' AS CLINOM,
				PROCOD collate Latin1_General_BIN AS COD,
				(SDCQTDPED-SDCQTDATD-SDCQTDRES) * SDCQTDEMB AS QTD, 
				TDPPRELOJ1 * (SDCQTDPED-SDCQTDATD-SDCQTDRES) * SDCQTDEMB AS VAL,
				SDCDATCAD AS DATCAD,
				DATEDIFF(DAY, SDCDATCAD, getdate()) AS DIAS_PEN,	
				LESCOD AS ESTLOC,
				COMPRAS,
				DISPONIVEL,
				EST,
				LOJA	
			
				FROM OPENROWSET(''SQLNCLI'', ''' + @serverIPRemoto + ''';''integros'';''int3gro5@15387'', ''

				SELECT 
				B.SDCNUM,
				SDCITE,
				B.PROCOD AS PROCOD, 
				E.CCSNOM, 
				SDCQTDPED, 
				SDCQTDATD,
				SDCQTDRES,
				SDCQTDEMB,
				SDCDATCAD,
				SDCPEN,
				LESCOD,
				ISNULL(TDPPRELOJ1, 0) AS TDPPRELOJ1,
				ISNULL((SELECT SUM(ESTQTDCMP) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE B.PROCOD = J.PROCOD AND ESTLOC IN(1,2) GROUP BY PROCOD), 0) AS COMPRAS,
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE B.PROCOD = J.PROCOD AND ESTLOC IN(1,2) GROUP BY PROCOD), 0) AS DISPONIVEL,
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE B.PROCOD = J.PROCOD AND ESTLOC IN(1) GROUP BY PROCOD), 0) AS EST,
				ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM ' + @bancoNome + '.dbo.TBS032 J(NOLOCK) WHERE B.PROCOD = J.PROCOD AND ESTLOC IN(2) GROUP BY PROCOD), 0) AS LOJA
			
				FROM ' + @bancoNome + '.dbo.TBS0761 B (NOLOCK)
				LEFT JOIN ' + @bancoNome + '.dbo.TBS076 C (NOLOCK) ON C.SDCNUM = B.SDCNUM
				LEFT JOIN ' + @bancoNome + '.dbo.TBS031 G (NOLOCK) ON B.PROCOD COLLATE Latin1_General_CI_AS = G.TDPPROCOD			
				LEFT JOIN ' + @bancoNome + '.dbo.TBS036 E (NOLOCK) ON C.CCSCOD = E.CCSCOD
			
				WHERE
				SDCPEN = ''''S'''' AND
				SDCQTDPED > (SDCQTDBAI +SDCQTDRES)			
				'') AS Sol				
				Where Sol.PROCOD collate Latin1_General_BIN IN(SELECT PROCOD FROM #ProdutosNF)'

				-- Executa a query acima que irá incluir registros na #pengeral
				INSERT INTO #pengeral
				exec(@Query)
			End
		End

		SET @count = @count + 1
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Tabela final...
	
	SELECT 
	A.*,	
	QTDENT,		-- Quantidade de entrada
	PRODES,
	PROUM1,
	NFENUM,
	NFESERDOC,
	NFECOD,
	NFENOM,
	NFEDATEMI

	FROM #pengeral AS A
	LEFT JOIN #ProdutosNF AS B ON B.PROCOD = PENCOD
	LEFT JOIN TBS010 (NOLOCK) AS C ON C.PROCOD = B.PROCOD
	
	ORDER BY PENCOD
/**/

--	SELECT * FROM #pengeral

End