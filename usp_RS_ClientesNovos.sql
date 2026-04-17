/*
====================================================================================================================================================================================
WREL093 - Clientes novos
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
30/01/2025 - WILLIAM
	- Troca da SP "usp_GetCodigosVendedores" pela "usp_Get_CodigosVendedores", recebendo o nome de vendedor como parametro e possibilidade de incluir vendedor 0(zero);
13/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Uso da SP "usp_GetCodigosVendedores" para obter códigos dos vendedores conforme parametro;	
	- Inclusão de filtros nas tabelas pela empresa, utilizando o parâmetro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
	- Uso de query dinamicas sendo executada via SP "sp_executesql";
====================================================================================================================================================================================
*/
--CREATE PROCEDURE [dbo].[usp_RS_ClientesNovos]
ALTER PROCEDURE [dbo].[usp_RS_ClientesNovos]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime,
    @vendedor varchar(5000),
	@grupovendedor varchar(500)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS002 smallint, @empresaTBS004 smallint, @empresaTBS091 smallint,
			@Data_De datetime, @Data_Ate datetime, @CodigosVendedor varchar(5000), @GruposVendedor varchar(500),
			@ParmDef nvarchar(500), @cmdSQL nvarchar(MAX);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @CodigosVendedor = @vendedor;
	SET @GruposVendedor = @grupovendedor;

-- Uso da funcao split, para as clausulas IN()
	-- Codigos dos grupos de vendedor
	If object_id('TempDB.dbo.#GRUPOSVEN') is not null
		DROP TABLE #GRUPOSVEN;
	SELECT 
		elemento as gruvencod
	INTO #GRUPOSVEN FROM fSplit(@GruposVendedor, ',')

-- Verificar se a tabela compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS091', @empresaTBS091 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos vendedores	
	IF OBJECT_ID('tempdb.dbo.#CodigosVendedores') IS NOT NULL
		DROP TABLE #CodigosVendedores;

	CREATE TABLE #CodigosVendedores(VENCOD INT)

	INSERT INTO #CodigosVendedores
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @CodigosVendedor, '', 'FALSE'; --FALSE = Nao incluir codigo zero

--	SELECT * FROM #CodigosVendedores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos registros dos vendedores

	IF OBJECT_ID('tempdb.dbo.#TBS004') IS NOT NULL
	   DROP TABLE #TBS004;

	SELECT 
		VENCOD,
		RTRIM(LTRIM(STR(B.VENCOD))) + ' - ' + RTRIM(LTRIM(VENNOM)) AS VENNOM,
		ISNULL(C.GVECOD, 0) AS GVECOD,
		ISNULL(RTRIM(LTRIM(STR(C.GVECOD))) + ' - ' + RTRIM(LTRIM(C.GVEDES)), '0 - SEM GRUPO') AS GVEDES
	INTO #TBS004
	FROM TBS004 B (NOLOCK)
		LEFT JOIN TBS091 C (NOLOCK) ON B.GVEEMPCOD = C.GVEEMPCOD AND B.GVECOD = C.GVECOD 
	WHERE
		VENEMPCOD = @empresaTBS004 AND
		VENCOD IN (SELECT VENCOD FROM #CodigosVendedores) AND 
		B.GVEEMPCOD = @empresaTBS091 AND	
		B.GVECOD IN (SELECT gruvencod FROM #GRUPOSVEN)

	UNION
	SELECT TOP 1 
		0,
		'0 - SEM VENDEDOR' AS VENNOM,
		0,
		'0 - SEM GRUPO' AS GVDES
	FROM TBS004 (NOLOCK)
	WHERE
	0 IN (SELECT VENCOD FROM #CodigosVendedores) AND 
	0 IN (SELECT gruvencod FROM #GRUPOSVEN)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		A.CLIDATCAD,
		CASE CLITIPPES
			WHEN 'J' THEN 'JURIDICA'
			WHEN 'F' THEN 'FISICA'
			ELSE ''
		END AS CLITIPPES,
		CLICOD, 
		RTRIM(LTRIM(CLINOM)) AS CLINOM,
		CLICGC, 
		CLICPF,
		A.CLICLA,
		A.CLILIC,
		CASE A.CLISIT
			WHEN 'A' THEN 'ATIVO'
			WHEN 'I' THEN 'INATIVO'
			ELSE ''
		END CLISIT,
		CASE WHEN A.CLIBLQTRN = 'S' THEN 'SIM' ELSE 'NAO' END AS CLIBLQTRN, -- CAMPO CLIBLQTRN SIGNIFICA SOMENTE A VISTA ? 
		A.CLIUSUALT,
		VENNOM,
		GVEDES

	FROM TBS002 A (NOLOCK)		
		LEFT JOIN #TBS004 B (NOLOCK) ON A.VENCOD = B.VENCOD	

	WHERE
		CLIEMPCOD = @empresaTBS002
		AND A.CLIDATCAD BETWEEN @Data_De AND @Data_Ate
		AND A.VENCOD IN(SELECT VENCOD FROM #TBS004)
	ORDER BY 
		CLIDATCAD, 
		CLICOD
END