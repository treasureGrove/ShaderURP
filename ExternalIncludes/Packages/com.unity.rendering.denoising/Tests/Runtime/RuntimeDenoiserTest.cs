using UnityEngine;
using UnityEngine.TestTools;
using NUnit.Framework;
using System.Collections;
using UnityEngine.Rendering.Denoising;

class RuntimeDenoiserTest
{
    static DenoiserType[] FixtureArgs =
    {
        DenoiserType.None,
        DenoiserType.OpenImageDenoise,
        DenoiserType.Optix,
        DenoiserType.Radeon
    };

    void PlayModeCreateDenoiserTest(DenoiserType denoiserType) {

        if (Denoiser.IsDenoiserTypeSupported(denoiserType) == false)
            return;

        // Create denoiser.
        Denoiser denoiser = new Denoiser();

        Denoiser.State result = denoiser.Init(denoiserType, 128, 128, 0, 0);
        Assert.AreEqual(Denoiser.State.Success, result);
    }

    [TestCaseSource("FixtureArgs")]
    public void CreateDenoiser(DenoiserType denoiserType)
    {
        PlayModeCreateDenoiserTest(denoiserType);
    }
}
