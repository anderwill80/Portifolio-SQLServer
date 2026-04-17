/*
====================================================================================================================================================================================
Retorna dias uteis com base na nova tabela de feriados(dbo.FERIADOS), que se esta a nivel de municipio(Codigo IBGE)
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
23/04/2025 WILLIAM
	- Melhoria no código, para corrigir obtencao da quantidade de feriados, quando tiver mais de um no mesmo dia, aconteceu em Taubate, dia 21/04/25; 
03/02/2025 WILLIAM
	- Troca do prefixo do nome da SP para "usp_Get_...";
12/04/2024 WILLIAM
	- Criacao;	
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_Get_DiasUteis_DEBUG]
ALTER PROC  [dbo].[usp_Get_DiasUteis]
	@uf char(2),
	@municipio int,
	@pdataDe date, 
	@pdataAte date,
	@ignoraDiasSemana varchar(20),
	@contaFeriados char(1),	
	@diasUteis int out,
	@feriados int out 
AS 
BEGIN 
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE @dataDe date, @dataAte date,
			@contador int = 0, @qferiados int = 0, @qferiadosValidos int = 0, @CurrentDate date, @EndDate date;

	-- Atribuicoes locais
	SET @dataDe = @pdataDe;
	SET @dataAte = @pdataAte;

	set datefirst 7; -- semana inicia no domingo (padr�o de DATEDIFF)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Monta a lista dos dias da semana a serem ignorados como dia �til
	-- 1=Domingo...7=S�bado

	If object_id('tempdb.dbo.#DiasSemana') is not null 
		drop table #DiasSemana	
			
    select 
		elemento as [diasemana]
	Into #DiasSemana From dbo.fSplit(@ignoraDiasSemana, ',')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria tabela Calendario data e o dia da semana da data, conforme o intervalo de datas...

	DECLARE @Calendario AS TABLE(
		SEMANA INT,
		DATA DATETIME
	)
	WHILE @contador <= (SELECT DATEDIFF(DD, @dataDe, @dataAte ))
	BEGIN 
		INSERT INTO @Calendario SELECT DATEPART(DW,(DATEADD(DD, @contador, @dataDe))), DATEADD(DD, @contador, @dataDe)

		SET @contador = @contador + 1
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Se contabiliza feriados v�lidos, desconsiderando os que caem nos dias da semana ignorados via par�metro(@ignoraDiasSemana)	
	IF UPPER(@contaFeriados) = 'S'	
	BEGIN
		SELECT @CurrentDate = @dataDe, @EndDate = @dataAte;

		WHILE @CurrentDate <= @EndDate
		BEGIN
			IF EXISTS (SELECT 1 FROM FERIADOS WHERE Data = @CurrentDate AND (nMunicipio = @municipio OR UF = 'BR' OR UF = @uf))
			BEGIN
				SET @qferiados = @qferiados + 1
			END;

			-- Verifica se a data atual é um feriado
			IF EXISTS (SELECT 1 FROM FERIADOS WHERE Data = @CurrentDate AND (nMunicipio = @municipio OR UF = 'BR' OR UF = @uf) AND DATEPART(weekday, Data) NOT IN(SELECT diasemana FROM #DiasSemana))
			BEGIN
				SET @qferiadosValidos = @qferiadosValidos + 1
			END;

			-- Incrementa a data para a próxima iteração
			SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
		END;
	END 	
						 	
	-- Retorna os dias �teis desconsiderando os dias da semana(SAB e/ou DOM) - os feriados v�lidos
	SET @diasUteis = (SELECT COUNT(SEMANA) FROM @Calendario WHERE SEMANA not in (select diasemana from #DiasSemana)) - @qferiadosValidos;

	SET @feriados = @qferiados;

	RETURN 
end
GO


