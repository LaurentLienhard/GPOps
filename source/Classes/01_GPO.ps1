class GPO
{
    <#
    .DESCRIPTION
        Represents a Group Policy Object with encapsulated state and behavior.
        This class manages GPO properties and linked organizational units.
    #>

    #region <Properties>

    [System.String]$DisplayName
    [System.Guid]$Id
    [System.String]$Domain
    [System.DateTime]$Created
    [System.DateTime]$Modified
    [System.Boolean]$IsEnabled
    [System.String]$Owner
    [System.Collections.Generic.List[string]]$LinkedOUs
    [System.String]$Description

    #endregion <Properties>

    #region <Constructor>

    GPO()
    {
        $this.LinkedOUs = [System.Collections.Generic.List[string]]::new()
    }

    GPO([object]$ADObject)
    {
        $this.DisplayName = $ADObject.DisplayName ?? ''
        $this.Id = $ADObject.Id ?? [guid]::Empty
        $this.Domain = $ADObject.Domain ?? ''
        $this.Created = $ADObject.Created ?? [System.DateTime]::MinValue
        $this.Modified = $ADObject.Modified ?? [System.DateTime]::MinValue
        $this.Owner = $ADObject.Owner ?? 'Unknown'
        $this.Description = $ADObject.Description ?? ''
        $this.IsEnabled = -not ($ADObject.GpoStatus -eq 'AllSettingsDisabled')
        $this.LinkedOUs = [System.Collections.Generic.List[string]]::new()
    }

    GPO([string]$Name, [System.Guid]$Id)
    {
        $this.DisplayName = $Name
        $this.Id = $Id
        $this.LinkedOUs = [System.Collections.Generic.List[string]]::new()
    }

    #endregion <Constructor>

    #region <Methods>

    [void] LinkToOu([string]$OuPath)
    {
        if ([string]::IsNullOrWhiteSpace($OuPath))
        {
            throw [System.ArgumentException]"OU path cannot be null or empty"
        }

        if ($this.LinkedOUs.Contains($OuPath))
        {
            return
        }

        $this.LinkedOUs.Add($OuPath)
    }

    [void] UnlinkFromOu([string]$OuPath)
    {
        if ([string]::IsNullOrWhiteSpace($OuPath))
        {
            throw [System.ArgumentException]"OU path cannot be null or empty"
        }

        $this.LinkedOUs.Remove($OuPath)
    }

    [void] UnlinkAll()
    {
        $this.LinkedOUs.Clear()
    }

    [string[]] GetLinkedOUs()
    {
        return $this.LinkedOUs.ToArray()
    }

    [int] GetLinkCount()
    {
        return $this.LinkedOUs.Count
    }

    [hashtable] ToHashtable()
    {
        return @{
            DisplayName = $this.DisplayName
            Id          = $this.Id
            Domain      = $this.Domain
            Created     = $this.Created
            Modified    = $this.Modified
            IsEnabled   = $this.IsEnabled
            Owner       = $this.Owner
            Description = $this.Description
            LinkedOUs   = $this.LinkedOUs.ToArray()
            LinkCount   = $this.GetLinkCount()
        }
    }

    [PSCustomObject] ToObject()
    {
        return [PSCustomObject]$this.ToHashtable()
    }

    [string] ToString()
    {
        return "$($this.DisplayName) [$($this.Id)]"
    }

    #endregion <Methods>
}
