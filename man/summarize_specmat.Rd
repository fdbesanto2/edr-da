% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/spectra_ci.R
\name{summarize_specmat}
\alias{summarize_specmat}
\title{Summarize a matrix of spectra}
\usage{
summarize_specmat(mat, alpha = 0.05, waves = 400:2500, ...)
}
\arguments{
\item{mat}{Matrix of spectra, waves x samples}

\item{alpha}{P value for quantiles}

\item{waves}{Wavelengths. Default = 400:2500}

\item{...}{Additional arguments to [PEcAnRTM::spectra]}
}
\description{
Summarize a matrix of spectra
}
