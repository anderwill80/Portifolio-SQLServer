/*
====================================================================================================================================================================================
Permite retornar o CNPJ e a sigla da empresa do grupo BMPT, a partir do código da empresa local, para ser usada em outras SPs que necessitam dessa informação
dessa forma fica padronizado as siglas de cada empresa;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
13/04/2026 WILLIAM
	- Criacao;
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_Get_CNPJSigla_EmpresaBMPT]
ALTER PROC [dbo].[usp_Get_CNPJSigla_EmpresaBMPT]
	@pEmpCod smallint,
	@pCNPJEmpresa VARCHAR(20) OUT,
	@pSiglaEmpresa char(2) OUT
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @EmpresaLocalCNPJ VARCHAR(20), @EmpresaLocalSigla VARCHAR(2);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod;		
	SET @EmpresaLocalCNPJ = (SELECT TOP 1 RTRIM(LTRIM(EMPCGC)) AS  EMPCGC FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa);
	
	-- Define o nome da empresa que esta executando o relatorio, para a tabela final
	SET @EmpresaLocalSigla =
	CASE
		WHEN @EmpresaLocalCNPJ = '05118717000156' then 'BB'
		WHEN @EmpresaLocalCNPJ = '52080207000117' then 'MI'
		WHEN @EmpresaLocalCNPJ = '44125185000136' then 'PY'
		WHEN @EmpresaLocalCNPJ = '41952080000162' then 'WP'
		WHEN @EmpresaLocalCNPJ = '65069593000198' then 'TM'
		WHEN @EmpresaLocalCNPJ = '65069593000350' then 'TD'
		WHEN @EmpresaLocalCNPJ = '65069593000279' then 'TT'				
	END

	-- Retorna CNPJ e sigla da empresa local BMPT
	SELECT @pCNPJEmpresa = @EmpresaLocalCNPJ, @pSiglaEmpresa = @EmpresaLocalSigla;
----------------------------------------------------------------------------------------------------------------------------------------------------------------
END