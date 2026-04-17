/*
====================================================================================================================================================================================
Retorna saldo atual da empresa local, para ser utilizado para gravar na tabela [SaldoGeral], que tera o seus dados acessados pelo relatorio "Saldo Geral";
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
13/04/2026 WILLIAM	
	- Uso da SP [usp_Get_CNPJSigla_EmpresaBMPT] para obter o CNPJ e a sigla da empresa local, ao invés de usar um CASE, para facilitar a manutenção futura, 
	caso haja necessidade de incluir novas empresas no grupo;
07/04/2026 WILLIAM
	- Criacao
	- Retirada do atributo [ALTERADO] da tabela final, sem uso;
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_Get_SaldoAtual]
ALTER PROC [dbo].[usp_Get_SaldoAtual]
	@pEmpCod smallint
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @EmpresaLocalCNPJ VARCHAR(20), @EmpresaLocalSigla VARCHAR(2);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod;		

	-- Obtem a sigla da empresa local, para ser utilizada na tabela final
	EXEC [usp_Get_CNPJSigla_EmpresaBMPT] @codigoEmpresa, @EmpresaLocalCNPJ OUT, @EmpresaLocalSigla OUT;	
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- SALDO ESTOQUE 1 
	IF OBJECT_ID ('TempDB.dbo.#EST1') is not null
	drop table #EST1

	SELECT 
	PROCOD,
	ESTQTDATU-ESTQTDRES AS EST

	into #EST1 
	FROM TBS032 B (nolock) 

	WHERE 
	ESTLOC = 1 AND ESTQTDATU - ESTQTDRES <> 0

	------------------------------------------------------------------------------------------------------------------------------

	-- SALDO ESTOQUE 2

	IF OBJECT_ID ('TempDB.dbo.#EST2') is not null
	drop table #EST2

	SELECT 
	PROCOD,
	ESTQTDATU - ESTQTDRES AS LOJ

	into #EST2
	FROM TBS032 B (nolock) 

	WHERE 
	ESTLOC = 2 AND ESTQTDATU - ESTQTDRES <> 0

	------------------------------------------------------------------------------------------------------------------------------

	-- SALDO ESTOQUE GERAL

	IF OBJECT_ID ('TempDB.dbo.#EST') is not null
	drop table #EST

	SELECT 
	PROCOD,
	SUM(ESTQTDRES) AS RES,
	SUM(ESTQTDPEN) AS PEN,
	SUM(ESTQTDCMP) AS CMP

	into #EST
	FROM TBS032 B (nolock) 

	WHERE 
	ESTLOC IN (1,2) AND 
	(ESTQTDATU <> 0 OR ESTQTDPEN <> 0 OR ESTQTDCMP <>0)

	GROUP BY 
	PROCOD

	------------------------------------------------------------------------------------------------------------------------------

	-- PEDIDO DE COMPRAS

	IF OBJECT_ID ('TempDB.dbo.#COM') is not null
	drop table #COM

	SELECT 
	B.PROCOD,
	B.PDCDES, 
	SUM((B.PDCQTD - B.PDCQTDENT) * B.PDCQTDEMB) AS QTD , 
	PDCDATPRE AS DAT

	INTO #COM
	FROM TBS0451 B (NOLOCK) 
	JOIN TBS045 C (NOLOCK) ON B.PDCNUM = C.PDCNUM

	WHERE 
	B.PDCQTD - B.PDCQTDENT - B.PDCQTDRES > 0 AND
	C.PDCBLQ ='N'

	GROUP BY 
	B.PROCOD,B.PDCDES,PDCDATPRE
													
	------------------------------------------------------------------------------------------------------------------------------
	-- TABELA FINAL 
	IF OBJECT_ID ('tempdb.dbo.#saldo') is not null
		drop table #saldo;

	SELECT 
		@EmpresaLocalSigla as 'UNIDADE',
		rtrim(ltrim(A.PROCOD)) as 'CODIGO',
		rtrim(ltrim(A.PRODES)) as 'DESCRICAO',							
		case when len(A.MARCOD) = 4 then rtrim(A.MARCOD) + ' - ' + rtrim(A.MARNOM) else right(('00' + ltrim(str(A.MARCOD))),3) + ' - ' + rtrim(A.MARNOM) end as 'MARCA',
		CASE WHEN PROUM1QTD < 2
			THEN PROUM1
			ELSE rtrim(PROUM1) + ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) 
		END as 'UNIDMEDIDA',
		CASE WHEN PROUM2QTD > 0 and PROPREUM2COR > 0
			THEN rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) 
			ELSE '' 
		END  AS UN2,
		ISNULL(C.LOJ,0) AS 'LOJA',						
		ISNULL(B.EST,0) AS 'DISPONIVEL',
		ISNULL(D.RES,0) AS 'RESERVADO',
		ISNULL(D.PEN,0) AS 'PENDENTE',
		ISNULL(E.QTD,0) AS 'COMPRAS',
		ISNULL(E.DAT,'') AS 'PRE_ENT',
		ISNULL(D.CMP,0) AS 'COMPRASTT',
		isnull(rtrim(ltrim(E.PDCDES)),'') AS 'DESCRICAOPDC',
		A.MARCOD,
		RTRIM(LTRIM(A.MARNOM)) AS MARNOM,
		PROPREUM1LOJ,
		PROPREUM2LOJ * PROUM2QTD AS PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR * PROUM2QTD AS PROPREUM2COR,
		ISNULL(F.NFSQTD,0) AS QTDTRANSITO

	INTO #saldo FROM TBS010 A (nolock)
		LEFT JOIN #EST1 B ON A.PROCOD = B.PROCOD
		LEFT JOIN #EST2 C ON A.PROCOD = C.PROCOD
		LEFT JOIN #EST D ON A.PROCOD = D.PROCOD
		LEFT JOIN #COM E ON A.PROCOD = E.PROCOD
		LEFT JOIN ItensEmTransito F ON A.PROCOD = F.PROCOD

	WHERE
		ISNULL(B.EST,0) <> 0 OR ISNULL(C.LOJ,0) <> 0 OR ISNULL(D.RES,0) <> 0 OR ISNULL(D.PEN,0) <> 0 OR ISNULL(D.CMP,0) <> 0 OR ISNULL(E.QTD,0) <> 0 OR ISNULL(F.NFSQTD,0) <> 0

----------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final na estrutura da tabela [SaldoGeral], com sigla da empresa do grupo BMPT.
	SELECT
		*
	FROM #saldo
	--WHERE CODIGO = '0410010'
----------------------------------------------------------------------------------------------------------------------------------------------------------------
END