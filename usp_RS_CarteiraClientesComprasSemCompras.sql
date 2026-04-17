/*
====================================================================================================================================================================================
WREL006 - CARTEIRA DE CLIENTE COM/SEM COMPRAS
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
09/02/2026 WILLIAM
	- Conversao do parametro de entrada de varchar para int: @codigoCliente;
08/05/2025 WILLIAM
	- Udo da SP "usp_Get_DWVendas" e usp_Get_DWDevolucaoVendas, para obter as informacoes de vendas e devolucao de vendas, respectivamente, 
	deixando o codigo mais "limpo";
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes;
	- Retirada de codigo sem uso;
15/08/2024 WILLIAM
	- Uso da funcao "RetiraAcento_V" para retirar os caracteres especiais e acentos que podem dar erro ao exportar para EXCEL;
18/07/2024 WILLIAM			
	- Alteracao do prefixo do nome da SP para "usp_RS"
	- Inlusao do parametro @empcod que atribuido ao ser chamado por dentro do Integros
	- Utilizacao da SP usp_ClientesGrupo em vez da sp_ClientesGrupo
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_CarteiraClientesComprasSemCompras_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_CarteiraClientesComprasSemCompras]
	@empcod smallint,
	@dataDe date = null,
	@dataAte date = null,
	@codigoCliente int = 0,
	@nomeCliente varchar(60) = '',
	@codigoVendedor varchar(100) = '',
	@nomeVendedor varchar(60) = '', 
	@VENDAS varchar(10) = 'T',
	@pGrupoBMPT char(1) = 'N'
AS
BEGIN
	
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE	@codigoEmpresa smallint, @data_De date,	@data_Ate date, @CLICOD int, @CLINOM varchar(60), @VENCOD varchar(100), @VENNOM varchar(60),
			@ComVendas varchar(10), @GrupoBMPT char(1), 
			@contabiliza varchar(10),
			@empresaTBS002 smallint, @empresaTBS004 smallint;

	-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @data_De = @dataDe;
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @CLICOD = @codigoCliente;
	SET @CLINOM = @nomecliente;
	SET @VENCOD = @codigoVendedor;
	SET @VENNOM = @nomeVendedor;
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);
	SET @ComVendas = @VENDAS;


-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');	

	-- Verificar se a tabela compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela de vendedores
	-- Obtem codigos dos vendedores via SP, incluindo codigo 0(zero)

	IF OBJECT_ID('tempdb.dbo.#CODVEN') IS NOT NULL
		DROP TABLE #CODVEN;

	CREATE TABLE #CODVEN (VENCOD INT)
	
	INSERT INTO #CODVEN
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @VENCOD, @VENNOM, 'TRUE';

	-- Refinamento dos vendedores
	IF OBJECT_ID('tempdb.dbo.#TBS004') IS NOT NULL 
		DROP TABLE #TBS004;

		SELECT
			VENCOD,
			RTRIM(LTRIM(VENNOM)) AS VENNOM
		INTO #TBS004 FROM TBS004 A (NOLOCK)

		WHERE 
			VENEMPCOD = @empresaTBS004 AND
			VENCOD IN(SELECT VENCOD FROM #CODVEN)

		UNION
		SELECT TOP 1
			0,
			'SEM VENDEDOR' AS VENNOM
		FROM TBS004 (NOLOCK)

		WHERE
			0 IN(SELECT VENCOD FROM #CODVEN)

------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem codigos dos cliente via SP

	IF OBJECT_ID('tempdb.dbo.#CODCLIENTES') IS NOT NULL
		DROP TABLE #CODCLIENTES;

	CREATE TABLE #CODCLIENTES (CLICOD INT)
	
	INSERT INTO #CODCLIENTES
	EXEC usp_Get_CodigosClientes @codigoEmpresa, '', @CLINOM, @GrupoBMPT;

	-- Refinamento dos clientes
	IF OBJECT_ID('tempdb.dbo.#TBS002') IS NOT NULL 
		DROP TABLE #TBS002;
   
	SELECT  
		A.VENCOD,
		B.VENNOM,
		CLICGC,
		CLICPF,
		CLICOD, 
		RTRIM(LTRIM(dbo.RetiraAcento_V(CLINOM, 3))) AS 'CLINOM',
		RTRIM(LTRIM(dbo.RetiraAcento_V(CLITEL, 3))) AS 'CLITEL',
		RTRIM(LTRIM(dbo.RetiraAcento_V(CLICONTAT, 3))) AS 'CLICONTAT',
		CLIDATCAD, 
		RTRIM(LTRIM(dbo.RetiraAcento_V(CLIEMAIL, 3))) AS 'CLIEMAIL',
		CLIPRICOM,
		CLIPCPVAL,
		CLIPCPNFS,
		CLIMCPDAT,
		CLIMCPVAL,
		CLIMCPNFS,
		CLIUCPDAT,
		CLIUCPVAL,
		CLIUCPNFS,
		CLISIT,
		RTRIM(LTRIM(dbo.RetiraAcento_V(CLIOBS, 3))) AS 'CLIOBS',
		CLIPORCOD,
		ISNULL((SELECT PORNOM FROM TBS063 C (NOLOCK) WHERE A.CLIPORCOD = C.PORCOD),'') AS PORNOM,
		CLICLA,
		CLILIC,
		CLILICVEN,
		CLIBLQ,
		CLITIPPES,
		CLIACUCOM,
		case when CLIQTDBAI > 0 
			then round(convert(decimal(10,4),CLIACUATR) / CLIQTDBAI,0) 
			else 0 
		end as CLIMEDATR,
		isnull(MUNNOM,'') as 'MUNNOM',
		CLICURABC

	INTO #TBS002 FROM TBS002 (NOLOCK) A
		INNER JOIN #TBS004 B ON A.VENCOD = B.VENCOD
		LEFT JOIN TBS003 M (NOLOCK) on M.UFESIG = A.UFESIG and M.MUNCOD = A.MUNCOD

	WHERE 
		CLIEMPCOD = @empresaTBS002 AND
		CLICOD IN (SELECT CLICOD FROM #CODCLIENTES)

--	SELECT * FROM #TBS002	

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza

	-- SELECT * FROM ##DWVendas;
/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,		
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,		
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza

	--  SELECT * FROM ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para obter informacao da tabela de METAS, e contabilizar as vendas e devolucoes por vendedor;

	;WITH
		vendas AS(
			SELECT
				codigoCliente,
				ISNULL(CASE SUBSTRING(CONVERT(CHAR(12), data, 103), 4, 2)
					WHEN '01' THEN '01 JAN' 
					WHEN '02' THEN '02 FEV' 
					WHEN '03' THEN '03 MAR' 
					WHEN '04' THEN '04 ABR' 
					WHEN '05' THEN '05 MAI' 
					WHEN '06' THEN '06 JUN' 
					WHEN '07' THEN '07 JUL' 
					WHEN '08' THEN '08 AGO' 
					WHEN '09' THEN '09 SET' 
					WHEN '10' THEN '10 OUT' 
					WHEN '11' THEN '11 NOV' 
					WHEN '12' THEN '12 DEZ' 
				END,'') AS MES,
				ISNULL(SUBSTRING(CONVERT(CHAR(12), data, 111), 1, 4),'') AS ANO,
				numeroDocumento,
				numeroSerieDocumento,
				valorTotal
			FROM ##DWVendas

			WHERE
				codigoCliente > 0			-- Somente vendas com clientes cadastrados
				AND documentoReferenciado = ''	-- Evita filtrar nota gerada via cupom fiscal, ja que temos os 2 registros da venda, o de cupom e o de nota;
		),
		-- Agrupa as vendas pelo ano, mes e cliente e notas
		vendas_agrupadas AS(
			SELECT
				codigoCliente,
				ANO,
				MES,			
				SUM(valorTotal) AS valorTotal,
				COUNT( DISTINCT numeroDocumento) AS QTD
			FROM vendas

			GROUP BY
				ANO,
				MES,
				codigoCliente
		),

		-- Contabiliza as devolucoes
		devolucoes AS(
			SELECT
				codigoCliente,
				ISNULL(CASE SUBSTRING(CONVERT(CHAR(12), data, 103), 4, 2)
					WHEN '01' THEN '01 JAN' 
					WHEN '02' THEN '02 FEV' 
					WHEN '03' THEN '03 MAR' 
					WHEN '04' THEN '04 ABR' 
					WHEN '05' THEN '05 MAI' 
					WHEN '06' THEN '06 JUN' 
					WHEN '07' THEN '07 JUL' 
					WHEN '08' THEN '08 AGO' 
					WHEN '09' THEN '09 SET' 
					WHEN '10' THEN '10 OUT' 
					WHEN '11' THEN '11 NOV' 
					WHEN '12' THEN '12 DEZ' 
				END,'') AS MES,
				ISNULL(SUBSTRING(CONVERT(CHAR(12), data, 111), 1, 4),'') AS ANO,
				valorTotal
			FROM ##DWDevolucaoVendas		
		),
		-- Agrupa as devolucoes pelo ano, mes e cliente e notas
		devolucoes_agrupadas AS(
			SELECT
				codigoCliente,
				ANO,
				MES,			
				SUM(valorTotal) AS valorTotal
			FROM devolucoes

			GROUP BY
				ANO,
				MES,
				codigoCliente
		),
		vendas_devolucoes AS(
			SELECT
				IIF(ROW_NUMBER() OVER (Partition by v.codigoCliente ORDER BY v.codigoCliente, v.MES) = 1 AND ISNULL(v.QTD, 0) > 0, 
					1,
					0
				) AS CLIQTD, -- MARCANDO OS CLIENTES QUE TIVEREM PELO MENOS UMA COMPRA NO PERIODO FILTRADO
				ISNULL(v.codigoCliente, d.codigoCliente) AS codigoCliente,
				ISNULL(v.MES, d.MES) AS MES, 
				ISNULL(v.ANO, d.ANO) AS ANO,
				ISNULL(v.QTD, 0) AS QTD,
				ISNULL(v.valorTotal, 0) AS valorTotal,
				ISNULL(d.valorTotal, 0) AS valorTotalDev

			FROM vendas_agrupadas v
				FULL JOIN devolucoes_agrupadas d ON d.codigoCliente = v.codigoCliente AND d.ANO = v.ANO AND d.MES = v.MES
				
		),
		clientes_com_vendas AS(
			SELECT 
				codigoCliente

			FROM vendas_devolucoes

			GROUP BY 
				codigoCliente 

			HAVING
				SUM(valorTotal) > 0
		),
		vendas_totais AS(		   
			SELECT 
				codigoCliente,
				CASE WHEN ROW_NUMBER() OVER (Partition by codigoCliente order by codigoCliente , MES) = 1 AND CASE WHEN codigoCliente IN (SELECT codigoCliente FROM clientes_com_vendas)	THEN 'SIM' ELSE 'NAO' END = 'SIM'
					THEN 1
					ELSE 0
				END AS CLIQTD, -- MARCANDO OS CLIENTES QUE TIVEREM PELO MENOS UMA COMPRA NO PERIODO FILTRADO 
				MES, 
				ANO,
				SUM(QTD) AS QTD, -- CONTANDO A QTD DE NOTAS FATURADAS POR MES
				CASE WHEN codigoCliente IN (SELECT codigoCliente FROM clientes_com_vendas)
					THEN 'SIM'
					ELSE 'NAO'
				END AS COMVENDAS,
				SUM(valorTotal) AS VALTOTNFS, 
				SUM(valorTotalDev) AS VALDEVNFS 

			FROM vendas_devolucoes

			GROUP BY 
				codigoCliente,
				MES, 
				ANO
		),
		tabela_final AS(
			SELECT 
				VENCOD,
				RIGHT(('0000' + CONVERT(VARCHAR(4), VENCOD)), 4) + ' - ' + RTRIM(VENNOM) AS VENDEDOR,
				ISNULL(MES, '') AS MES, 
				ISNULL(ANO, '') AS ANO,
				ISNULL(QTD, 0) AS QTD, 

				CASE WHEN CLIUCPVAL = 0 
					THEN 'NUNCA'
					ELSE 
						CASE WHEN CLIUCPVAL > 0 AND ISNULL(COMVENDAS,'NAO') = 'NAO'
							THEN 'NAO'
							ELSE 'SIM'
						END
				END AS COMVENDAS,
				CLICOD,
				ISNULL(CLIQTD,0) AS CLIQTD,
				CLINOM,
				ISNULL(VALTOTNFS, 0) AS VALTOTNFS,
				ISNULL(VALDEVNFS, 0) AS VALDEVNFS,
				RTRIM(LTRIM(CLITEL)) AS CLITEL, 
				RTRIM(LTRIM(CLICONTAT)) AS CLICONTAT, 
				CONVERT(DATE,CLIDATCAD) AS CLIDATCAD, 
				RTRIM(LTRIM(CLIEMAIL)) AS CLIEMAIL,
				CONVERT(DATE,CLIPRICOM) AS CLIPRICOM,
				CLIPCPVAL,
				CLIPCPNFS,
				CONVERT(DATE,CLIMCPDAT) AS CLIMCPDAT,
				CLIMCPVAL,
				CLIMCPNFS,
				CONVERT(DATE,CLIUCPDAT) AS CLIUCPDAT,
				CLIUCPVAL,
				CLIUCPNFS,
				CLISIT,
				RTRIM(LTRIM(CLIOBS)) AS CLIOBS,
				CLIPORCOD,
				RTRIM(LTRIM(PORNOM)) AS PORNOM,
				CLICLA,
				CLILIC,
				CLILICVEN,
				CLIBLQ,
				CLITIPPES,
				CLIACUCOM,
				CLIMEDATR,
				MUNNOM,
				CLICURABC,

				(IIF(CLITIPPES = 'J', dbo.FormatarCnpj(CLICGC), dbo.FormatarCpf(CLICPF))) AS CLICGCCPF

			FROM #TBS002 A 
				LEFT JOIN vendas_totais B (NOLOCK) ON A.CLICOD = B.codigoCliente 
		)

		-- TABELA FINAL		
		SELECT 
			CASE COMVENDAS WHEN 'NAO' THEN 1 ELSE 0 END as NAO,
			CASE COMVENDAS WHEN 'NUNCA' THEN 1 ELSE 0 END as NUNCA,
			*
		FROM tabela_final 

		WHERE 
			COMVENDAS IN (CASE WHEN @ComVendas = 'T' THEN COMVENDAS ELSE UPPER(RTRIM(@ComVendas)) END)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

End
