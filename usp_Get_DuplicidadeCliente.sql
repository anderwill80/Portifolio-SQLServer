/*
====================================================================================================================================================================================
Permite verificar se um cliente existe, buscando nas bases de dados das empresas do grupo, através do CPF ou CNPJ, e caso exista, retorna uma tabela com os dados
que sera usada por outra SP [USP_EXISTECLIENTE],que por sua vez, será usada pelo Integros;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
13/04/2026 WILLIAM
	- Criacao;
	- Uso da SP [usp_Get_CNPJSigla_EmpresaBMPT] para obter o CNPJ e a sigla da empresa local, ao invés de usar um CASE, para facilitar a manutenção futura, 
	caso haja necessidade de incluir novas empresas no grupo;
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_Get_DuplicidadeCliente]
ALTER PROC [dbo].[usp_Get_DuplicidadeCliente]            
	@pEmpCod smallint,
	@pTipoPessoa char(1),
	@pDocumento varchar(14)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @EmpresaLocalCNPJ VARCHAR(20), @EmpresaLocalSigla VARCHAR(2), @tipoPessoa char(1), @documento varchar(14),
			@empresaTBS002 smallint, @empresaTBS004 smallint;

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod;		
	SET @tipoPessoa = @pTipoPessoa;
	SET @documento = @pDocumento;	
	
	-- Obtem a sigla da empresa local, para ser utilizada na tabela final
	EXEC [usp_Get_CNPJSigla_EmpresaBMPT] @codigoEmpresa, @EmpresaLocalCNPJ OUT, @EmpresaLocalSigla OUT;	

	-- Verificar se a tabela e compartilhada ou exclusiva					
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	IF object_id('tempdb.dbo.#CLIENTE') IS NOT NULL 
	  DROP TABLE #CLIENTE;	

	CREATE TABLE #CLIENTE(
		empresa char(2), 
		codigo int, 
		nome varchar(60), 
		ultima_compra date, 
		vendedor varchar(35)
	)

	IF @tipoPessoa = 'J'
	BEGIN
		IF (SELECT TOP 1 1 FROM TBS002 WITH (NOLOCK) WHERE CLICGC = @documento) > 0
		BEGIN
			INSERT INTO #CLIENTE
			SELECT 
				@EmpresaLocalSigla,
				c.CLICOD,
				RTRIM(c.CLINOM),
				c.CLIUCPDAT,
				ISNULL(v.VENNOM, '') AS 'VENNOM'
			FROM TBS002 c WITH (NOLOCK)
			LEFT JOIN TBS004 v WITH (NOLOCK) ON v.VENEMPCOD = @empresaTBS004 AND v.VENCOD = c.VENCOD
			WHERE 
				c.CLIEMPCOD = @empresaTBS002
				AND c.CLICGC = @documento
		END				
	END
	ELSE
	BEGIN
		IF (SELECT TOP 1 1 FROM TBS002 WITH (NOLOCK) WHERE CLICPF = @documento) > 0
		BEGIN
			INSERT INTO #CLIENTE
			SELECT 
				@EmpresaLocalSigla,
				c.CLICOD,
				RTRIM(c.CLINOM),
				c.CLIUCPDAT,
				ISNULL(v.VENNOM, '') AS 'VENNOM'
			FROM TBS002 c WITH (NOLOCK)
			LEFT JOIN TBS004 v WITH (NOLOCK) ON v.VENEMPCOD = @empresaTBS004 AND v.VENCOD = c.VENCOD
			WHERE 
				c.CLIEMPCOD = @empresaTBS002
				AND c.CLICPF = @documento
		END	
	END
----------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Tabela final, para ser utilizada pela SP [USP_EXISTECLIENTE]
	SELECT
		*
	FROM #CLIENTE
----------------------------------------------------------------------------------------------------------------------------------------------------------------
END