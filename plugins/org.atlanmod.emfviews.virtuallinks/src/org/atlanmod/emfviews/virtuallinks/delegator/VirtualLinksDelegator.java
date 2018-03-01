/*******************************************************************************
 * Copyright (c) 2018 Armines
 * Copyright (c) 2013 INRIA
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   fmdkdd - refactoring and extension
 *   Juan David Villa Calle - initial API and implementation
 *******************************************************************************/

package org.atlanmod.emfviews.virtuallinks.delegator;

import java.util.Arrays;
import java.util.List;

import org.atlanmod.emfviews.virtuallinks.WeavingModel;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IConfigurationElement;
import org.eclipse.core.runtime.IExtension;
import org.eclipse.core.runtime.Platform;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;

public class VirtualLinksDelegator {

  static final String EXTENSION_POINT = "org.atlanmod.emfviews.virtuallinks.delegator";

  IVirtualLinksDelegate delegate;
  URI matchingModelURI;

  public VirtualLinksDelegator(URI matchingModelURI) {
    this.matchingModelURI = matchingModelURI;
    String extension = matchingModelURI.fileExtension();

    // Find the virtual links delegate that is the default handler for
    // the file extension

    IExtension[] handlers = Platform.getExtensionRegistry()
        .getExtensionPoint(EXTENSION_POINT).getExtensions();

    // Get all handlers for this file extension.  Default handlers are picked first.
    IConfigurationElement handler = Arrays.stream(handlers)
        .flatMap(h -> Arrays.stream(h.getConfigurationElements()))
        .filter(c -> extension.compareToIgnoreCase(c.getAttribute("fileExtension")) == 0)
        .sorted((a, b) -> Boolean.parseBoolean(a.getAttribute("default")) ? -1 : 1)
        .findFirst()
        .orElseThrow(() -> new IllegalStateException(String.format("No registered virtual links delegator for extension %s", extension)));

    try {
      delegate = (IVirtualLinksDelegate) handler.createExecutableExtension("class");
    } catch (CoreException e) {
      throw new IllegalStateException(String.format("Cannot instantiate virtual links delegator"), e);
    }
  }

  public WeavingModel createWeavingModel(List<Resource> contributingModels) throws Exception {
    return delegate.createWeavingModel(matchingModelURI, contributingModels);
  }

}
